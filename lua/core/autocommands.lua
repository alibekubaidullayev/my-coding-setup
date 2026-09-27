vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		-- vim.highlight was renamed to vim.hl in nvim 0.11
		local hl = vim.hl or vim.highlight
		hl.on_yank({ timeout = 180 })
	end,
})

vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	callback = function()
		vim.opt_local.shell = os.getenv("SHELL")
	end,
})

-- Soft bigfile guard (replaces snacks.bigfile)
vim.api.nvim_create_autocmd("BufReadPre", {
	group = vim.api.nvim_create_augroup("bigfile", { clear = true }),
	callback = function(ev)
		local ok, size = pcall(vim.fn.getfsize, ev.file)
		if ok and size > 1.5 * 1024 * 1024 then
			vim.b[ev.buf].bigfile = true
			vim.opt_local.swapfile = false
			vim.opt_local.foldmethod = "manual"
			vim.opt_local.undolevels = -1
			vim.schedule(function()
				pcall(vim.treesitter.stop, ev.buf)
			end)
		end
	end,
})

-- Cursorline only in the focused window
local cursorline_group = vim.api.nvim_create_augroup("active-cursorline", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "InsertLeave" }, {
	group = cursorline_group,
	callback = function()
		if vim.w.auto_cursorline then
			vim.wo.cursorline = true
			vim.w.auto_cursorline = nil
		end
	end,
})
vim.api.nvim_create_autocmd({ "WinLeave" }, {
	group = cursorline_group,
	callback = function()
		if vim.wo.cursorline then
			vim.w.auto_cursorline = true
			vim.wo.cursorline = false
		end
	end,
})

-- Equalize splits when the terminal is resized
vim.api.nvim_create_autocmd("VimResized", {
	group = vim.api.nvim_create_augroup("resize-splits", { clear = true }),
	callback = function()
		local current = vim.fn.tabpagenr()
		vim.cmd("tabdo wincmd =")
		vim.cmd("tabnext " .. current)
	end,
})

-- Keep lsp.log from growing forever (nvim never trims it): start fresh past 5 MB
local lsp_log = vim.fn.stdpath("state") .. "/lsp.log"
local lsp_log_stat = vim.uv.fs_stat(lsp_log)
if lsp_log_stat and lsp_log_stat.size > 5 * 1024 * 1024 then
	os.remove(lsp_log)
end

-- Pick up files the coding agent rewrites on disk. FocusGained covers switching
-- back from the agent's tmux pane; the timer covers edits that land while nvim
-- stays focused. Only unmodified buffers are reloaded silently; a buffer with
-- unsaved edits gets Neovim's usual conflict prompt on focus/enter instead.
vim.o.autoread = true
local reload_group = vim.api.nvim_create_augroup("agent-reload", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "TermLeave" }, {
	group = reload_group,
	callback = function()
		if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
})
local reload_timer = vim.uv.new_timer()
reload_timer:start(1000, 1000, vim.schedule_wrap(function()
	-- Not while typing, in the cmdline, or at a hit-enter / more prompt
	if vim.api.nvim_get_mode().mode:match("^[icRr]") or vim.fn.getcmdwintype() ~= "" then
		return
	end
	local seen = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if not seen[buf] and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
			and vim.api.nvim_buf_get_name(buf) ~= ""
		then
			seen[buf] = true
			vim.cmd("silent! checktime " .. buf)
		end
	end
end))
