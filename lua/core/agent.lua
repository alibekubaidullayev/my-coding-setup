-- Hand code back to the coding agent (Claude Code / Codex) running in a tmux
-- pane: `path:10-24` references with the selected code, pasted into the
-- agent's prompt (not submitted) so you can add your comment and send it.
local M = {}

-- Files written from this nvim since the last <leader>ae
local edited = {}

local function relpath(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	local root = vim.fs.root(buf, ".git")
	return root and vim.fs.relpath(root, name) or vim.fn.fnamemodify(name, ":.")
end

--- `path:line` in normal mode; `path:start-end` plus the code in visual mode
local function reference()
	local mode = vim.fn.mode()
	if not mode:match("^[vV\22]") then
		return relpath(0) .. ":" .. vim.fn.line(".")
	end
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then
		s, e = e, s
	end
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	return table.concat({
		relpath(0) .. ":" .. (s == e and s or (s .. "-" .. e)),
		"```" .. vim.bo.filetype,
		table.concat(lines, "\n"),
		"```",
	}, "\n")
end

local function tmux(args, input)
	local out = vim.fn.system(vim.list_extend({ "tmux" }, args), input)
	return vim.v.shell_error == 0 and out or nil
end

-- Claude Code's native binary shows up as its version number (e.g. "2.1.283")
local function is_agent(cmd)
	return cmd:match("claude") or cmd:match("codex") or cmd:match("opencode") or cmd == "node"
		or cmd:match("^%d+%.%d+%.%d+$")
end

--- Agent pane: in nvim's window first (preferring the pane you came from),
--- then anywhere in the session. A lone other pane in the window also counts.
local function agent_pane()
	if not vim.env.TMUX or not vim.env.TMUX_PANE then
		return nil
	end
	local fmt = "#{pane_id}\t#{pane_last}\t#{pane_current_command}"
	for _, scope in ipairs({ {}, { "-s" } }) do
		local out = tmux(vim.list_extend({ "list-panes", "-t", vim.env.TMUX_PANE, "-F", fmt }, scope))
		local agents, others = {}, {}
		for _, line in ipairs(vim.split(out or "", "\n", { trimempty = true })) do
			local id, last, cmd = line:match("^(%S+)\t(%d)\t(.*)$")
			if id and id ~= vim.env.TMUX_PANE then
				table.insert(others, id)
				if is_agent(cmd) then
					table.insert(agents, last == "1" and 1 or #agents + 1, id)
				end
			end
		end
		if agents[1] then
			return agents[1]
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

--- Paste text into the agent's prompt without submitting; clipboard fallback
function M.send(text)
	local pane = agent_pane()
	if not pane then
		vim.fn.setreg("+", text)
		vim.notify("No agent pane found; copied to clipboard", vim.log.levels.WARN)
		return
	end
	-- -p: bracketed paste, so newlines in the code don't submit the prompt
	if tmux({ "load-buffer", "-b", "nvim-agent", "-" }, text .. "\n")
		and tmux({ "paste-buffer", "-p", "-d", "-b", "nvim-agent", "-t", pane })
	then
		focus(pane)
	else
		vim.fn.setreg("+", text)
		vim.notify("tmux paste failed; copied to clipboard", vim.log.levels.WARN)
	end
end

function M.send_edited()
	local files = vim.tbl_keys(edited)
	if #files == 0 then
		vim.notify("No files edited since the last note")
		return
	end
	table.sort(files)
	M.send("I edited these files myself; re-read them before continuing:\n- " .. table.concat(files, "\n- "))
	edited = {}
end

vim.api.nvim_create_autocmd("BufWritePost", {
	group = vim.api.nvim_create_augroup("agent-edited-files", { clear = true }),
	callback = function(ev)
		if vim.bo[ev.buf].buftype == "" and vim.fs.root(ev.buf, ".git") then
			edited[relpath(ev.buf)] = true
		end
	end,
})

vim.keymap.set({ "n", "x" }, "<leader>ay", function()
	local ref = reference()
	vim.fn.setreg("+", ref)
	vim.notify("Copied " .. ref:match("^[^\n]+"))
end, { desc = "Agent: copy reference (+ selection)" })

vim.keymap.set({ "n", "x" }, "<leader>as", function()
	M.send(reference())
end, { desc = "Agent: send reference (+ selection) to agent pane" })

vim.keymap.set("n", "<leader>ae", M.send_edited, { desc = "Agent: send list of files I edited" })

vim.keymap.set("n", "<leader>aa", function()
	local pane = agent_pane()
	if pane then
		focus(pane)
	else
		vim.notify("No agent pane found", vim.log.levels.WARN)
	end
end, { desc = "Agent: focus agent pane" })

return M
