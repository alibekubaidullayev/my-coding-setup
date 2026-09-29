-- Agent → nvim. Claude Code and Codex hooks (scripts/agent-hook.lua) call
-- on_event() over RPC, so nvim knows what the agent is doing instead of
-- polling for it:
--   * statusline: working / needs approval / done, per agent session
--   * files are reloaded the moment the agent writes them
--   * a finished turn is announced with its changed files
--
-- Each nvim registers its RPC socket and repository root in
-- stdpath("state")/agent-bridge/<pid>; the hook messages the ones whose root
-- matches the agent's.
local M = {}

--- Open the turn's review automatically when the agent stops
M.review_on_stop = false

--- session id -> { agent = "claude"|"codex", state = "working"|"waiting"|"done", since, files }
M.sessions = {}

local dir = vim.fn.stdpath("state") .. "/agent-bridge"
local registration = dir .. "/" .. vim.fn.getpid()

local function root()
	local cwd = vim.fn.getcwd()
	local r = vim.fs.root(cwd, ".git") or cwd
	return vim.uv.fs_realpath(r) or r
end

local function register()
	-- Not for an nvim the agent itself opened (Ctrl-G prompt editor), nor headless ones
	if vim.env.CLAUDECODE or vim.v.servername == "" or #vim.api.nvim_list_uis() == 0 then
		return
	end
	vim.fn.mkdir(dir, "p")
	local f = io.open(registration, "w")
	if f then
		f:write(vim.json.encode({ server = vim.v.servername, root = root() }))
		f:close()
	end
end

local function session(id, agent)
	id = id or "default"
	M.sessions[id] = M.sessions[id] or { state = "done", since = os.time(), files = {} }
	M.sessions[id].agent = agent or M.sessions[id].agent or "claude"
	return M.sessions[id]
end

local function title(s, what)
	return (s.agent == "codex" and "Codex" or "Claude") .. " " .. what
end

-- Reload right away; a buffer with unsaved edits is left alone (and flagged)
local function reload(file)
	local buf = file and vim.fn.bufnr(file)
	if not buf or buf == -1 or not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	if vim.bo[buf].modified then
		vim.notify(
			"The agent rewrote " .. vim.fn.fnamemodify(file, ":~:.") .. ", which has unsaved changes here",
			vim.log.levels.WARN,
			{ title = "Agent" }
		)
	else
		vim.cmd("silent! checktime " .. buf)
	end
end

local function finished(s, turn)
	vim.cmd("silent! checktime")
	local files = turn and turn.files or vim.tbl_keys(s.files)
	if #files == 0 then
		return
	end
	table.sort(files)
	local shown = vim.list_slice(files, 1, 6)
	if #files > #shown then
		table.insert(shown, ("… %d more"):format(#files - #shown))
	end
	vim.notify(
		("Changed %d file%s:\n  %s\n<leader>gt review turn · <leader>gd review all"):format(
			#files,
			#files == 1 and "" or "s",
			table.concat(shown, "\n  ")
		),
		vim.log.levels.INFO,
		{ title = title(s, "finished") }
	)
	if M.review_on_stop and turn and not require("core.review").in_review() then
		require("core.turns").review({ id = turn.id, start = turn.start })
	end
end

function M.on_event(ev)
	local s = session(ev.session, ev.agent)
	local event = ev.event
	if event == "UserPromptSubmit" then
		s.state, s.since, s.files = "working", os.time(), {}
	elseif event == "PostToolUse" then
		if s.state ~= "working" then
			s.state, s.since = "working", os.time()
		end
		for _, file in ipairs(ev.files or {}) do
			s.files[vim.fn.fnamemodify(file, ":.")] = true
			reload(file)
		end
	elseif event == "Notification" or event == "PermissionRequest" then
		local msg = ev.message or ""
		if ev.kind == "permission_prompt" or msg:lower():find("permission") then
			s.state, s.since = "waiting", os.time()
			vim.notify(msg, vim.log.levels.WARN, { title = title(s, "needs approval") })
		end
	elseif event == "Stop" or event == "Interrupt" then
		s.state, s.since = "done", os.time()
		finished(s, ev.turn)
	elseif event == "SessionEnd" then
		M.sessions[ev.session or "default"] = nil
	end
	vim.cmd.redrawstatus()
end

local rank = { waiting = 3, working = 2, done = 1 }
local hl = { waiting = "DiagnosticWarn", working = "DiagnosticOk", done = "Comment" }

--- Most urgent session, and how many sessions there are
local function current()
	local best, n = nil, 0
	for _, s in pairs(M.sessions) do
		n = n + 1
		if not best or rank[s.state] > rank[best.state] then
			best = s
		end
	end
	return best, n
end

--- Statusline text: agent state plus pending review comments
function M.status()
	local parts = {}
	local s, n = current()
	if s then
		local text = ({ working = "working", waiting = "needs approval", done = "done" })[s.state]
		if s.state == "working" then
			local secs = os.time() - s.since
			text = text .. " " .. (secs < 60 and (secs .. "s") or (math.floor(secs / 60) .. "m"))
		end
		table.insert(parts, "\u{f06a9} " .. s.agent .. " " .. text .. (n > 1 and (" ×" .. n) or ""))
	end
	local comments = package.loaded["core.comments"] and require("core.comments").count() or 0
	if comments > 0 then
		table.insert(parts, "\u{f0188} " .. comments)
	end
	return table.concat(parts, "  ")
end

--- Statusline colour for the current state
function M.color()
	local s = current()
	local spec = vim.api.nvim_get_hl(0, { name = hl[s and s.state or "done"], link = false })
	return spec.fg and { fg = ("#%06x"):format(spec.fg) } or nil
end

local group = vim.api.nvim_create_augroup("agent-bridge", { clear = true })
vim.api.nvim_create_autocmd({ "UIEnter", "DirChanged" }, { group = group, callback = register })
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = group,
	callback = function()
		os.remove(registration)
	end,
})

return M
