-- Coding-agent hook → nvim, for Claude Code and Codex. Run as
-- `nvim -l <this file> <HookEvent> [claude|codex]` with the hook's JSON on stdin.
--
-- Claude Code, ~/.claude/settings.json:
--   "hooks": {
--     "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "nvim -l \"$HOME/.config/nvim/scripts/agent-hook.lua\" UserPromptSubmit" }] }],
--     "PostToolUse":      [{ "matcher": "*", "hooks": [{ ... PostToolUse, "async": true }] }],
--     "Notification":     [{ "matcher": "",  "hooks": [{ ... Notification, "async": true }] }],
--     "Stop":             [{ "hooks": [{ ... Stop }] }],
--     "SessionEnd":       [{ "hooks": [{ ... SessionEnd }] }]
--   }
-- Codex, ~/.codex/hooks.json: the same shape with `... <Event> codex`, and
-- PermissionRequest + Interrupt in place of Notification (approve once in /hooks).
--
-- It snapshots each agent turn into git (lua/core/turns.lua), rings the tmux
-- bell when the agent stops or needs you, and forwards the event to every nvim
-- open on the same repository (lua/core/bridge.lua).
--
-- Rules: never write to stdout (Claude adds UserPromptSubmit stdout to the
-- prompt; Codex rejects non-JSON), and always exit 0 (exit 2 blocks the agent).
local config = vim.fn.stdpath("config")
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

--- Files an apply_patch (Codex's edit tool) touches, as absolute paths
local function patch_files(patch, cwd)
	if type(patch) == "table" then
		patch = table.concat(vim.tbl_filter(function(v)
			return type(v) == "string"
		end, patch), "\n")
	end
	local files = {}
	for line in (type(patch) == "string" and patch or ""):gmatch("[^\n]+") do
		local path = line:match("^%*%*%* Add File: (.+)$")
			or line:match("^%*%*%* Update File: (.+)$")
			or line:match("^%*%*%* Delete File: (.+)$")
			or line:match("^%*%*%* Move to: (.+)$")
		if path then
			path = vim.trim(path)
			table.insert(files, vim.fs.normalize(path:match("^/") and path or (cwd .. "/" .. path)))
		end
	end
	return files
end

local function main()
	local event = arg[1] or ""
	local agent = arg[2] or "claude"
	local ok, data = pcall(vim.json.decode, io.read("*a") or "", { luanil = { object = true, array = true } })
	if not ok or type(data) ~= "table" then
		data = {}
	end
	local cwd = data.cwd or vim.uv.cwd()
	local session = data.session_id or "default"
	local turns = require("core.turns")
	local root = turns.root(cwd)

	-- The agent's own tmux pane (inherited), so nvim pastes into it and nothing else
	local payload = { event = event, agent = agent, session = session, cwd = cwd, pane = vim.env.TMUX_PANE }
	if event == "UserPromptSubmit" then
		payload.prompt = data.prompt
		if root then
			turns.start(root, session, data.prompt)
		end
	elseif event == "Stop" or event == "SessionEnd" or event == "Interrupt" then
		payload.turn = root and turns.finish(root, session) or nil
	elseif event == "PostToolUse" then
		local input = type(data.tool_input) == "table" and data.tool_input or {}
		payload.tool = data.tool_name
		local file = input.file_path or input.notebook_path
		payload.files = file and { file } or patch_files(input.command or input.patch or input.input, cwd)
	elseif event == "Notification" then
		payload.message = data.message
		payload.kind = data.notification_type
	elseif event == "PermissionRequest" then
		-- Codex asks before a tool runs; show what it wants
		local input = type(data.tool_input) == "table" and data.tool_input or {}
		local what = type(input.command) == "string" and input.command:match("^[^\n]*") or ""
		payload.kind = "permission_prompt"
		payload.message = ("%s wants to use %s%s"):format(
			agent == "codex" and "Codex" or "The agent",
			data.tool_name or "a tool",
			what ~= "" and (": " .. what:sub(1, 80)) or ""
		)
	end

	-- Bell on the agent's pane: tmux marks the window, Ghostty the tab
	local wants_you = event == "Stop" or event == "Notification" or event == "PermissionRequest"
	if wants_you and vim.env.TMUX_PANE then
		local tty = vim.system({ "tmux", "display", "-p", "-t", vim.env.TMUX_PANE, "#{pane_tty}" }, { text = true }):wait()
		local f = tty.code == 0 and io.open(vim.trim(tty.stdout), "w")
		if f then
			f:write("\a")
			f:close()
		end
	end

	-- Forward to every nvim registered for this repository
	local target = root or vim.uv.fs_realpath(cwd) or cwd
	local dir = vim.fn.stdpath("state") .. "/agent-bridge"
	if not vim.uv.fs_stat(dir) then
		return
	end
	for name in vim.fs.dir(dir) do
		local path = dir .. "/" .. name
		local f = io.open(path)
		local entry = f and select(2, pcall(vim.json.decode, f:read("*a")))
		if f then
			f:close()
		end
		if type(entry) == "table" and entry.root == target then
			local ok_conn, chan = pcall(vim.fn.sockconnect, "pipe", entry.server, { rpc = true })
			if ok_conn and chan > 0 then
				-- A notification never waits on nvim, so a busy editor can't stall the agent
				vim.rpcnotify(chan, "nvim_exec_lua", "require('core.bridge').on_event(...)", { payload })
				vim.wait(20)
				vim.fn.chanclose(chan)
			else
				os.remove(path) -- that nvim is gone
			end
		end
	end
end

local ok, err = pcall(main)
if not ok then
	io.stderr:write("agent-hook: " .. tostring(err) .. "\n")
end
os.exit(0)
