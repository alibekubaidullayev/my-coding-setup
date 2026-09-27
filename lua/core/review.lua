-- Review mode: CodeDiff tabs used to review agent changes.
-- While a review tab is open, decorations that compete with diff colours are
-- switched off, and format-on-save leaves reviewed files alone so a one-line
-- fix doesn't reformat the agent's whole file into the diff.
local M = {}

local tabs = {}
local rainbow_off = {}
local ibl_was_enabled = false
local zoomed = false

M.explorer_width = 30
-- Below this many columns per pane, open the inline layout instead of
-- side-by-side (VS Code does the same when space is limited). `t` flips it.
M.min_pane_width = 100

--- True when bufnr (0 = current) is displayed in a review tab
function M.is_reviewing(bufnr)
	if not bufnr or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
		if tabs[vim.api.nvim_win_get_tabpage(win)] then
			return true
		end
	end
	return false
end

-- Review keys mapped here rather than through CodeDiff's config: CodeDiff
-- installs mappings as raw bytes, so <C-j> becomes the legacy <NL> and
-- <C-S-j> can't be expressed at all. Ghostty (kitty keyboard protocol) and
-- tmux extended-keys send the distinct keys, which would miss them.
local review_keys = {
	-- { lhs, CodeDiff API function name or function, desc, fallback outside a review tab }
	{ "<C-j>", "next_hunk", "Next hunk (review)", function() vim.cmd.wincmd("j") end },
	{ "<C-S-j>", "next_file", "Next file (review)" },
	{ "<C-S-k>", "prev_file", "Previous file (review)" },
	-- Quick open (as in VS Code), scoped to the files in the review
	{ "<C-p>", function() M.pick_file() end, "Pick review file", function() vim.cmd("normal! " .. vim.v.count1 .. "k") end },
}
local mapped = {}

local function map_review_keys(buf)
	mapped[buf] = true
	for _, key in ipairs(review_keys) do
		local lhs, fn, desc, fallback = unpack(key)
		vim.keymap.set("n", lhs, function()
			-- The same file buffer can also be open in a non-review tab
			if tabs[vim.api.nvim_get_current_tabpage()] then
				if type(fn) == "function" then
					fn()
				else
					require("codediff")[fn]()
				end
			elseif fallback then
				fallback()
			end
		end, { buffer = buf, desc = desc })
	end
end

-- File buffers change as you move through the explorer, so re-scan the tab
local function prepare_tab(tab)
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return
	end
	local ok, rainbow = pcall(require, "rainbow-delimiters")
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_win_get_config(win).relative == "" and not mapped[buf] then
			map_review_keys(buf)
		end
		if ok and not rainbow_off[buf] and rainbow.is_enabled(buf) then
			rainbow.disable(buf)
			rainbow_off[buf] = true
		end
	end
end

local function enter()
	if package.loaded["ibl"] then
		ibl_was_enabled = require("ibl.config").get_config(-1).enabled
		if ibl_was_enabled then
			vim.cmd("IBLDisable")
		end
	end
	if package.loaded["illuminate"] then
		require("illuminate").pause()
	end
end

local function leave()
	if ibl_was_enabled then
		pcall(vim.cmd, "IBLEnable")
		ibl_was_enabled = false
	end
	if package.loaded["illuminate"] then
		require("illuminate").resume()
	end
	local ok, rainbow = pcall(require, "rainbow-delimiters")
	for buf in pairs(rainbow_off) do
		if ok and vim.api.nvim_buf_is_valid(buf) then
			rainbow.enable(buf)
		end
	end
	rainbow_off = {}
	for buf in pairs(mapped) do
		if vim.api.nvim_buf_is_valid(buf) then
			for _, key in ipairs(review_keys) do
				pcall(vim.keymap.del, "n", key[1], { buffer = buf })
			end
		end
	end
	mapped = {}
end

-- The agent usually shares nvim's tmux window: zoom nvim's pane while
-- reviewing so the diff gets the whole screen. Jumping to the agent pane
-- (<leader>aa / <leader>as) unzooms; prefix+z zooms back.
local function tmux_window()
	if not vim.env.TMUX_PANE then
		return nil
	end
	local out = vim.fn.system({ "tmux", "display", "-p", "-t", vim.env.TMUX_PANE, "#{window_zoomed_flag} #{window_panes} #{window_width}" })
	local flag, panes, width = out:match("^(%d) (%d+) (%d+)")
	if vim.v.shell_error ~= 0 or not flag then
		return nil
	end
	return { zoomed = flag == "1", panes = tonumber(panes), width = tonumber(width) }
end

local function zoom_in()
	local win = tmux_window()
	if win and not win.zoomed and win.panes > 1 then
		vim.fn.system({ "tmux", "resize-pane", "-Z", "-t", vim.env.TMUX_PANE })
		zoomed = true
		-- Let the resize reach nvim before CodeDiff lays out its windows
		vim.wait(300, function()
			return vim.o.columns >= win.width
		end, 10)
	end
end

local function zoom_out()
	if not zoomed then
		return
	end
	zoomed = false
	local win = tmux_window()
	if win and win.zoomed then
		vim.fn.system({ "tmux", "resize-pane", "-Z", "-t", vim.env.TMUX_PANE })
	end
end

local function layout_flag(args)
	if args and (args:find("--inline", 1, true) or args:find("--side-by-side", 1, true)) then
		return ""
	end
	-- Two panes, each losing ~6 columns to line numbers and signs
	local pane = (vim.o.columns - M.explorer_width) / 2 - 6
	return pane < M.min_pane_width and " --inline" or ""
end

--- Open the review tab (working tree + index), or close it when already in it.
--- args: extra :CodeDiff arguments, e.g. "--staged" or "origin/HEAD..."
function M.toggle(args)
	local current = vim.api.nvim_get_current_tabpage()
	if tabs[current] then
		-- Same close path as CodeDiff's own `q` (internal API; tabclose as fallback)
		if not pcall(require("codediff.ui.lifecycle").close, current) then
			vim.cmd("tabclose")
		end
		return
	end
	-- Plain review: jump back to an existing review tab instead of opening another
	if not args then
		for tab in pairs(tabs) do
			if vim.api.nvim_tabpage_is_valid(tab) then
				vim.api.nvim_set_current_tabpage(tab)
				return
			end
		end
	end
	zoom_in()
	vim.cmd("CodeDiff" .. (args and (" " .. args) or "") .. layout_flag(args))
end

function M.in_review()
	return tabs[vim.api.nvim_get_current_tabpage()] == true
end

--- Telescope over the files in the current review; picking one opens it in
--- the diff. Uses CodeDiff internals (explorer tree), the same way its own
--- ]f/[f navigation does.
function M.pick_file()
	local tab = vim.api.nvim_get_current_tabpage()
	local panel = require("codediff.ui.lifecycle").get_panel(tab)
	if not (panel and panel.view and panel.name == "explorer") then
		vim.notify("This review has no file list", vim.log.levels.WARN)
		return
	end
	local explorer = panel.view
	local files = require("codediff.ui.explorer.tree").get_all_files(explorer.tree)
	if #files == 0 then
		vim.notify("No files in this review", vim.log.levels.WARN)
		return
	end
	local root = explorer.data.git_root

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	pickers
		.new({}, {
			prompt_title = "Review Files",
			finder = finders.new_table({
				results = files,
				entry_maker = function(file)
					local d = file.data
					local new = d.status == "??" or d.status == "A"
					return {
						value = d.path,
						data = d,
						display = ("%-2s %s%s"):format(d.status or "", d.path, d.group == "staged" and "  (staged)" or ""),
						ordinal = d.path,
						path = root .. "/" .. d.path,
						-- git_file_diff shows new files whole, others as `git diff HEAD`
						status = new and "??" or nil,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.git_file_diff.new({ cwd = root }),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not entry then
						return
					end
					-- Keep the explorer cursor in step, as ]f/[f do
					if vim.api.nvim_win_is_valid(explorer.winid) then
						for line = 1, vim.api.nvim_buf_line_count(explorer.bufnr) do
							local node = explorer.tree:get_node(line)
							if node and node.data and node.data.path == entry.data.path and node.data.group == entry.data.group then
								vim.api.nvim_win_set_cursor(explorer.winid, { line, 0 })
								break
							end
						end
					end
					explorer.on_file_select(entry.data)
				end)
				return true
			end,
		})
		:find()
end

--- Ignore leading/trailing whitespace in CodeDiff and in native diff mode
function M.toggle_whitespace()
	local on = not vim.o.diffopt:find("iwhite")
	if on then
		vim.opt.diffopt:append("iwhite")
	else
		vim.opt.diffopt:remove("iwhite")
	end
	if package.loaded["codediff.config"] then
		require("codediff.config").options.diff.ignore_trim_whitespace = on
		local tab = vim.api.nvim_get_current_tabpage()
		if tabs[tab] then
			-- Internal API (re-renders the selected file); harmless if it moves
			pcall(function()
				require("codediff.ui.refresh").reopen(tab)
			end)
		end
	end
	vim.notify("Diff whitespace: " .. (on and "ignored" or "shown"))
end

local group = vim.api.nvim_create_augroup("review-mode", { clear = true })

vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "CodeDiffOpen",
	callback = function(ev)
		local tab = ev.data and ev.data.tabpage
		if not tab then
			return
		end
		if next(tabs) == nil then
			enter()
		end
		tabs[tab] = true
		vim.schedule(function()
			prepare_tab(tab)
		end)
	end,
})

-- CodeDiff swaps file buffers into the tab as you move through the explorer
vim.api.nvim_create_autocmd("BufWinEnter", {
	group = group,
	callback = function()
		local tab = vim.api.nvim_get_current_tabpage()
		if tabs[tab] then
			vim.schedule(function()
				prepare_tab(tab)
			end)
		end
	end,
})

vim.api.nvim_create_autocmd("User", {
	group = group,
	pattern = "CodeDiffClose",
	callback = function(ev)
		local tab = ev.data and ev.data.tabpage
		if not tab or not tabs[tab] then
			return
		end
		tabs[tab] = nil
		if next(tabs) == nil then
			leave()
			zoom_out()
		end
	end,
})

-- `s` stages/unstages the file under the cursor in the file list (same as `-`)
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "codediff-explorer",
	callback = function(ev)
		vim.keymap.set("n", "s", "-", { buffer = ev.buf, remap = true, desc = "Stage/unstage file" })
	end,
})

return M
