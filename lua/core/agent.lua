-- Hand code back to the coding agent (Claude Code / Codex) running in a tmux
-- pane: `path:10-24` references with the selected code, pasted into the
-- agent's prompt (not submitted) so you can add your comment and send it.
local M = {}

local function relpath(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local root = vim.fs.root(buf, ".git")
	return root and vim.fs.relpath(root, name) or vim.fn.fnamemodify(name, ":.")
end
M.relpath = relpath

local function repo_root()
	local cwd = vim.fn.getcwd()
	return vim.fs.root(cwd, ".git") or cwd
end

--- Absolute path -> repo-relative (unchanged when outside the repo)
local function rel(path)
	return vim.fs.relpath(repo_root(), path) or vim.fn.fnamemodify(path, ":~:.")
end

--- Per-repository file under stdpath("state")/<kind>/
function M.state_file(kind, ext)
	local dir = vim.fn.stdpath("state") .. "/" .. kind
	vim.fn.mkdir(dir, "p")
	return dir .. "/" .. repo_root():gsub("[/\\:]", "%%") .. ext
end

--- Where a buffer's lines live, for the agent: repo-relative path, plus a
--- note on the revision for CodeDiff's read-only panes
function M.location(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name:match("^codediff://") then
		local ok, vf = pcall(require, "codediff.core.virtual_file")
		local parsed = ok and { vf.parse_url(name) } or {}
		local rev, path = parsed[2], parsed[3]
		if path then
			return path, rev and (rev:match("^:") and "staged version" or ("at " .. rev:sub(1, 10)))
		end
	end
	return relpath(buf)
end

--- `path:line` in normal mode; `path:start-end` plus the code in visual mode
local function reference()
	local path, note = M.location(0)
	note = note and (" (" .. note .. ")") or ""
	local mode = vim.fn.mode()
	if not mode:match("^[vV\22]") then
		return path .. ":" .. vim.fn.line(".") .. note
	end
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then
		s, e = e, s
	end
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	return table.concat({
		path .. ":" .. (s == e and s or (s .. "-" .. e)) .. note,
		"```" .. vim.bo.filetype,
		table.concat(lines, "\n"),
		"```",
	}, "\n")
end

local function tmux(args, input)
	local out = vim.fn.system(vim.list_extend({ "tmux" }, args), input)
	return vim.v.shell_error == 0 and out or nil
end

-- How sure a pane command is to be an agent: 2 certain, 1 maybe, nil no.
-- Claude Code's native binary shows up as its version number (e.g. "2.1.283");
-- "node" is the npm-installed one, but also any dev server.
local function agent_score(cmd)
	if cmd:match("claude") or cmd:match("codex") or cmd:match("opencode") or cmd:match("^%d+%.%d+%.%d+$") then
		return 2
	end
	return cmd == "node" and 1 or nil
end

local shells = { zsh = true, bash = true, fish = true, sh = true }

--- Agent pane: the one the agent's hooks reported (exact), else a guess: in
--- nvim's window first (preferring the pane you came from), then anywhere in
--- the session. A lone other pane in the window also counts.
local function agent_pane()
	if not vim.env.TMUX or not vim.env.TMUX_PANE then
		return nil
	end
	-- Still alive and not back at the shell (agent quit without SessionEnd)
	for _, pane in ipairs(require("core.bridge").panes()) do
		local cmd = pane ~= vim.env.TMUX_PANE and tmux({ "display", "-p", "-t", pane, "#{pane_current_command}" })
		if cmd and not shells[vim.trim(cmd)] then
			return pane
		end
	end
	local fmt = "#{pane_id}\t#{pane_last}\t#{pane_current_command}"
	for _, scope in ipairs({ {}, { "-s" } }) do
		local out = tmux(vim.list_extend({ "list-panes", "-t", vim.env.TMUX_PANE, "-F", fmt }, scope))
		local best, best_score, others = nil, 0, {}
		for _, line in ipairs(vim.split(out or "", "\n", { trimempty = true })) do
			local id, last, cmd = line:match("^(%S+)\t(%d)\t(.*)$")
			if id and id ~= vim.env.TMUX_PANE then
				table.insert(others, id)
				local score = agent_score(cmd)
				score = score and (score * 2 + (last == "1" and 1 or 0))
				if score and score > best_score then
					best, best_score = id, score
				end
			end
		end
		if best then
			return best
		end
		if #scope == 0 and #others == 1 then
			return others[1]
		end
	end
end

local function focus(pane)
	tmux({ "select-window", "-t", pane })
	tmux({ "select-pane", "-t", pane })
end

--- Paste text into the agent's prompt without submitting; clipboard fallback.
--- Returns true when it reached the agent pane.
function M.send(text)
	local pane = agent_pane()
	if not pane then
		vim.fn.setreg("+", text)
		vim.notify("No agent pane found; copied to clipboard", vim.log.levels.WARN)
		return false
	end
	-- -p: bracketed paste, so newlines in the code don't submit the prompt
	if tmux({ "load-buffer", "-b", "nvim-agent", "-" }, text .. "\n")
		and tmux({ "paste-buffer", "-p", "-d", "-b", "nvim-agent", "-t", pane })
	then
		focus(pane)
		return true
	end
	vim.fn.setreg("+", text)
	vim.notify("tmux paste failed; copied to clipboard", vim.log.levels.WARN)
	return false
end

local MAX_DIFF = 300

--- Your edits since the agent last saw the tree (its last turn, or the last
--- time it was told), as a diff. Works from the turn snapshots, so edits made
--- outside nvim (lazygit, the shell) count too.
function M.send_edited()
	local turns = require("core.turns")
	local root = turns.root()
	if not root then
		vim.notify("Not in a git repository", vim.log.levels.WARN)
		return
	end
	local base = turns.baseline(root)
	if not base then
		vim.notify("No agent turn recorded yet to diff against", vim.log.levels.WARN)
		return
	end
	if require("core.bridge").busy()
		and vim.fn.confirm("The agent is mid-turn; its edits so far would show up as yours. Send anyway?", "&Send\n&Cancel", 2) ~= 1
	then
		return
	end
	local now = turns.tree(root)
	local diff = now and turns.git(root, { "diff", "--no-color", "--no-ext-diff", "--no-renames", base, now })
	if not diff or diff == "" then
		vim.notify("No edits since the agent's last turn")
		return
	end
	local files = turns.git(root, { "diff", "--name-only", "--no-renames", base, now }) or ""
	local out = {
		"I edited these files myself since your last turn; re-read them before changing them:",
		"- " .. table.concat(vim.split(files, "\n", { trimempty = true }), "\n- "),
	}
	local lines = select(2, diff:gsub("\n", "")) + 1
	if lines <= MAX_DIFF then
		vim.list_extend(out, { "", "```diff", diff, "```" })
	else
		table.insert(out, ("\n(The diff is %d lines; read the files for the details.)"):format(lines))
	end

	local unsaved = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if vim.bo[buf].modified and vim.bo[buf].buftype == "" and vim.fs.relpath(root, name) then
			unsaved = unsaved + 1
		end
	end
	if unsaved > 0 then
		vim.notify(("%d unsaved buffer%s not included"):format(unsaved, unsaved == 1 and "" or "s"), vim.log.levels.WARN)
	end
	if M.send(table.concat(out, "\n")) then
		turns.mark_told(root, now)
	end
end

-- ── hand failures to the agent ───────────────────────────────────────────────

local severity_name = { "ERROR", "WARN", "INFO", "HINT" }

--- Diagnostics as a fix-it list. scope: "buffer", "selection" or "all".
--- Buffer and project skip hints; a selection includes everything in it.
function M.send_diagnostics(scope)
	local bufnr, first, last
	if scope ~= "all" then
		bufnr = vim.api.nvim_get_current_buf()
	end
	if scope == "selection" then
		first, last = vim.fn.line("v"), vim.fn.line(".")
		if first > last then
			first, last = last, first
		end
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	end
	local min = scope == "selection" and vim.diagnostic.severity.HINT or vim.diagnostic.severity.INFO
	local diags = vim.tbl_filter(function(d)
		return d.severity <= min and (not first or (d.lnum + 1 >= first and d.lnum + 1 <= last))
	end, vim.diagnostic.get(bufnr))
	if #diags == 0 then
		vim.notify("No diagnostics to send")
		return
	end
	-- Errors first, so the cap below never drops them for warnings
	table.sort(diags, function(a, b)
		if a.severity ~= b.severity then
			return a.severity < b.severity
		end
		if a.bufnr ~= b.bufnr then
			return a.bufnr < b.bufnr
		end
		return a.lnum < b.lnum
	end)
	local out = { "Fix these diagnostics (from my editor's language servers):" }
	for _, d in ipairs(vim.list_slice(diags, 1, 60)) do
		local line = vim.api.nvim_buf_get_lines(d.bufnr, d.lnum, d.lnum + 1, false)[1] or ""
		table.insert(out, ("- %s:%d:%d [%s%s] %s\n  `%s`"):format(
			relpath(d.bufnr),
			d.lnum + 1,
			d.col + 1,
			severity_name[d.severity],
			d.source and (" " .. d.source) or "",
			d.message:gsub("\n", " "),
			vim.trim(line)
		))
	end
	if #diags > 60 then
		table.insert(out, ("… and %d more"):format(#diags - 60))
	end
	M.send(table.concat(out, "\n"))
end

--- The quickfix list: build errors, grep hits, hunks (<leader>hq), …
function M.send_quickfix()
	local qf = vim.fn.getqflist({ items = 1, title = 1 })
	local items = vim.tbl_filter(function(it)
		return it.valid == 1
	end, qf.items)
	if #items == 0 then
		vim.notify("Quickfix list is empty")
		return
	end
	local out = { ("Quickfix list%s:"):format(qf.title ~= "" and (" (" .. qf.title .. ")") or "") }
	for _, it in ipairs(vim.list_slice(items, 1, 100)) do
		local name = it.bufnr > 0 and relpath(it.bufnr) or "?"
		table.insert(out, ("- %s:%d: %s"):format(name, it.lnum, vim.trim(it.text)))
	end
	if #items > 100 then
		table.insert(out, ("… and %d more"):format(#items - 100))
	end
	M.send(table.concat(out, "\n"))
end

-- Latest finished neotest run, captured by the consumer below
local last_run

--- neotest consumer (registered in plugins/debug.lua): remembers the last
--- complete run so its failures can be handed over
function M.neotest_consumer(client)
	client.listeners.results = function(adapter_id, results, partial)
		if not partial then
			last_run = { adapter = adapter_id, results = results }
		end
	end
	return {}
end

local function strip_ansi(text)
	return (text:gsub("\27%[[%d;?]*[%a]", ""):gsub("\r", ""))
end

--- Failing tests from the last run, with their errors and output
function M.send_test_failures()
	if not last_run then
		vim.notify("No test run yet (<leader>tt / <leader>tf)", vim.log.levels.WARN)
		return
	end
	local failed = {}
	for id, result in pairs(last_run.results) do
		if result.status == "failed" and id:find("::", 1, true) then
			failed[id] = result
		end
	end
	-- Namespaces fail along with their tests; keep only the innermost ids
	local ids = {}
	for id in pairs(failed) do
		local parent = false
		for other in pairs(failed) do
			if other ~= id and vim.startswith(other, id .. "::") then
				parent = true
				break
			end
		end
		if not parent then
			table.insert(ids, id)
		end
	end
	if #ids == 0 then
		vim.notify("No failing tests in the last run")
		return
	end
	table.sort(ids)

	local adapter = last_run.adapter:match("^[^:]+") or last_run.adapter
	local out = { ("%d failing test%s (%s):"):format(#ids, #ids == 1 and "" or "s", adapter) }
	for i, id in ipairs(ids) do
		local file, name = id:match("^(.-)::(.+)$")
		local result = failed[id]
		if i > 10 then
			table.insert(out, ("- %s::%s"):format(rel(file), name))
		else
			local block = { ("%d. %s::%s"):format(i, rel(file), name) }
			for _, err in ipairs(result.errors or {}) do
				table.insert(block, ("   error%s: %s"):format(err.line and (" at line " .. (err.line + 1)) or "", strip_ansi(err.message)))
			end
			local short = result.short and strip_ansi(result.short) or ""
			if short ~= "" then
				local lines = vim.split(vim.trim(short), "\n")
				if #lines > 40 then
					lines = vim.list_extend({ "…" }, vim.list_slice(lines, #lines - 39))
				end
				vim.list_extend(block, { "   ```", table.concat(lines, "\n"), "   ```" })
			end
			table.insert(out, table.concat(block, "\n"))
		end
	end
	if #ids > 10 then
		table.insert(out, 12, "Also failing:")
	end
	M.send(table.concat(out, "\n\n"))
end

--- Agent memory (CLAUDE.md / AGENTS.md) nearest to this file, in a float, so
--- a mistake caught in review becomes a rule on the spot
function M.open_memory()
	local root = repo_root()
	local start = vim.api.nvim_buf_get_name(0)
	start = start ~= "" and not start:match("^%a+://") and vim.fs.dirname(start) or root
	local found = vim.fs.find({ "CLAUDE.md", "AGENTS.md" }, { upward = true, path = start, stop = vim.fs.dirname(root) })[1]
	local file = found or (root .. "/CLAUDE.md")
	local buf = vim.fn.bufadd(file)
	vim.fn.bufload(buf)
	vim.bo[buf].buflisted = true
	local width = math.min(100, vim.o.columns - 8)
	local height = math.min(30, vim.o.lines - 6)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		border = "rounded",
		title = " " .. vim.fn.fnamemodify(file, ":~:.") .. (found and "" or " (new)") .. " ",
		title_pos = "center",
		footer = " q close (writes) ",
		footer_pos = "center",
	})
	vim.wo[win].wrap = true
	vim.keymap.set("n", "q", function()
		if vim.bo[buf].modified then
			vim.cmd("silent write")
		end
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, desc = "Save and close" })
	-- The file stays open as a normal buffer: give `q` back once the float is gone
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			pcall(vim.keymap.del, "n", "q", { buffer = buf })
		end,
	})
end

-- ── keymaps ─────────────────────────────────────────────────────────────────

local function map(modes, lhs, fn, desc)
	vim.keymap.set(modes, lhs, fn, { desc = "Agent: " .. desc })
end
local function lazy(mod, fn, ...)
	local args = { ... }
	return function()
		require(mod)[fn](unpack(args))
	end
end

map({ "n", "x" }, "<leader>ay", function()
	local ref = reference()
	vim.fn.setreg("+", ref)
	vim.notify("Copied " .. ref:match("^[^\n]+"))
end, "copy reference (+ selection)")
map({ "n", "x" }, "<leader>as", function()
	M.send(reference())
end, "send reference (+ selection) now")
map("n", "<leader>ae", M.send_edited, "send my edits since last turn")
map("n", "<leader>aa", function()
	local pane = agent_pane()
	if pane then
		focus(pane)
	else
		vim.notify("No agent pane found", vim.log.levels.WARN)
	end
end, "focus agent pane")

-- Review comments + prompt draft, sent together with <leader>aS
map({ "n", "x" }, "<leader>ac", lazy("core.comments", "add"), "comment on line/selection")
map({ "n", "x" }, "<leader>ar", lazy("core.comments", "reject"), "reject hunk/selection with reason")
map("n", "<leader>ax", lazy("core.comments", "delete"), "delete comment under cursor")
map("n", "<leader>al", lazy("core.comments", "list"), "list review comments")
map("n", "<leader>aX", function()
	if vim.fn.confirm("Discard all review comments and the prompt draft?", "&Discard\n&Cancel", 2) == 1 then
		require("core.comments").clear()
		require("core.prompt").clear()
	end
end, "discard comments + draft")
map("n", "<leader>aS", lazy("core.comments", "submit"), "submit draft + comments")
map("n", "<leader>aC", lazy("core.comments", "submit_comments"), "send comments only (keep draft)")
map("n", "<leader>aP", lazy("core.comments", "restore_sent"), "restore last submitted draft + comments")
map("n", "<leader>ap", lazy("core.prompt", "toggle"), "prompt draft")
map({ "n", "x" }, "<leader>ai", function()
	require("core.prompt").append(reference())
end, "add reference to draft")

-- Failures
map("n", "<leader>ad", function()
	M.send_diagnostics("buffer")
end, "send buffer diagnostics")
map("x", "<leader>ad", function()
	M.send_diagnostics("selection")
end, "send diagnostics in selection")
map("n", "<leader>aD", function()
	M.send_diagnostics("all")
end, "send all diagnostics")
map("n", "<leader>aq", M.send_quickfix, "send quickfix list")
map("n", "<leader>at", M.send_test_failures, "send failing tests")

-- Turns (the review side lives at <leader>gt / <leader>gT)
map("n", "<leader>aU", lazy("core.turns", "undo_last"), "undo last agent turn")
map("n", "<leader>am", M.open_memory, "edit CLAUDE.md / AGENTS.md")

-- Review comments left from the last session: load them so they show again
vim.api.nvim_create_autocmd("UIEnter", {
	group = vim.api.nvim_create_augroup("agent-comments-restore", { clear = true }),
	once = true,
	callback = function()
		if vim.uv.fs_stat(M.state_file("agent-comments", ".json")) then
			require("core.comments")
		end
	end,
})

return M
