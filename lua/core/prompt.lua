-- Prompt draft: a markdown buffer (one per repository, kept on disk) for
-- writing longer instructions with the full editor, collecting references as
-- you read code, and sending it together with the review comments
-- (core/comments.lua). Opens as a float; the text survives restarts.
local M = {}

--- Inserted with <C-t> in the draft
M.templates = {
	{ "Minimal diff", "Make the smallest change that does this. No refactors, renames or unrelated formatting." },
	{ "Plan first", "Before changing anything, explain what's going on and propose a plan. Wait for my OK." },
	{ "Tests first", "Write a failing test for this first and show it fails, then make it pass." },
	{ "Review only", "Review this for bugs and risky assumptions. List issues by severity; don't change code yet." },
	{
		"Match the codebase",
		"Follow the patterns and style of the surrounding code; reuse existing helpers instead of adding new ones.",
	},
	{
		"Verify",
		"When done, run the relevant tests/linters and show me the result. Don't claim it works without running it.",
	},
}

local win

local function path()
	return require("core.agent").state_file("agent-prompts", ".md")
end

local function buffer()
	local buf = vim.fn.bufadd(path())
	if not vim.api.nvim_buf_is_loaded(buf) then
		vim.fn.bufload(buf)
		vim.bo[buf].buflisted = false
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].filetype = "markdown"
	end
	return buf
end

local function save(buf)
	if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent noautocmd write")
		end)
	end
end

--- Draft text ("" when empty)
function M.text()
	local buf = vim.fn.bufnr(path())
	if buf == -1 then
		local f = io.open(path())
		local text = f and f:read("*a") or ""
		if f then
			f:close()
		end
		return vim.trim(text)
	end
	return vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
end

function M.clear()
	local buf = buffer()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
	save(buf)
	M.close()
end

--- Append a block (a reference, some code) to the draft
function M.append(text)
	local buf = buffer()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local empty = #lines == 0 or (#lines == 1 and lines[1] == "")
	local new = vim.split(text, "\n")
	if empty then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)
	else
		vim.api.nvim_buf_set_lines(buf, -1, -1, false, vim.list_extend({ "" }, new))
	end
	save(buf)
	vim.notify(("Added to prompt draft (%d lines) · <leader>ap to open"):format(#new))
end

local function insert(text)
	vim.api.nvim_put({ text }, "c", false, true)
end

--- @path mention of a file picked with Telescope
local function insert_file()
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local target = vim.api.nvim_get_current_win()
	local root = vim.fs.root(vim.fn.getcwd(), ".git") or vim.fn.getcwd()
	require("telescope.builtin").find_files({
		cwd = root,
		prompt_title = "Mention file",
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if entry and vim.api.nvim_win_is_valid(target) then
					vim.api.nvim_set_current_win(target)
					insert("@" .. (entry.value or entry[1]) .. " ")
					vim.cmd("startinsert")
				end
			end)
			return true
		end,
	})
end

local function insert_template()
	vim.ui.select(M.templates, {
		prompt = "Prompt template",
		format_item = function(t)
			return t[1]
		end,
	}, function(choice)
		if choice then
			insert(choice[2])
		end
	end)
end

function M.close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	win = nil
end

function M.open()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
		return
	end
	local buf = buffer()
	local width = math.min(100, vim.o.columns - 8)
	local height = math.min(20, vim.o.lines - 6)
	win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " \u{f06a9} Prompt draft ",
		title_pos = "center",
		footer = " <C-s> send (+ comments) · <C-f> @file · <C-t> template · q close ",
		footer_pos = "center",
	})
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].conceallevel = 2

	if not vim.b[buf].agent_prompt_maps then
		vim.b[buf].agent_prompt_maps = true
		local function map(modes, lhs, fn, desc)
			vim.keymap.set(modes, lhs, fn, { buffer = buf, desc = desc })
		end
		map({ "n", "i" }, "<C-s>", function()
			vim.cmd("stopinsert")
			require("core.comments").submit()
		end, "Send draft + review comments")
		map({ "n", "i" }, "<C-f>", insert_file, "Mention a file")
		map({ "n", "i" }, "<C-t>", insert_template, "Insert template")
		map("n", "q", M.close, "Close draft")
		vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
			buffer = buf,
			callback = function()
				save(buf)
			end,
		})
	end
end

function M.toggle()
	if win and vim.api.nvim_win_is_valid(win) then
		save(vim.api.nvim_win_get_buf(win))
		M.close()
	else
		M.open()
	end
end

return M
