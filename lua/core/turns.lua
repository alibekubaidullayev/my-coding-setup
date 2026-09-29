-- Agent turns: a git snapshot of the working tree when you send a prompt and
-- when the agent stops, so every turn can be reviewed or undone on its own.
--
-- scripts/agent-hook.lua calls start()/finish() from Claude Code's hooks. A turn
-- is stored as a commit (the end snapshot) whose parent is the start snapshot,
-- appended to the reflog of refs/agent/turns: one ref, so `git log --all` only
-- gains a single extra line. Snapshots include untracked files (minus
-- .gitignore) and never touch the index, which review mode uses as "reviewed".
--
-- This file also runs outside the editor (nvim -l), so keep UI requires lazy.
local M = {}

M.ref = "refs/agent/turns"
local START_REF = "refs/agent/start/"

local identity = {
	GIT_AUTHOR_NAME = "agent-turns",
	GIT_AUTHOR_EMAIL = "agent-turns@localhost",
	GIT_COMMITTER_NAME = "agent-turns",
	GIT_COMMITTER_EMAIL = "agent-turns@localhost",
}

--- Run git in root; trimmed stdout, or nil and stderr on failure
function M.git(root, args, env)
	local r = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true, env = env }):wait()
	if r.code ~= 0 then
		return nil, vim.trim(r.stderr or "")
	end
	return vim.trim(r.stdout or "")
end

--- Repository root for a directory (realpath), or nil outside git
function M.root(dir)
	local out = M.git(dir or vim.fn.getcwd(), { "rev-parse", "--show-toplevel" })
	return out and out ~= "" and (vim.uv.fs_realpath(out) or out) or nil
end

--- Tree object for the current working tree, built in a throwaway index
function M.tree(root)
	local index = M.git(root, { "rev-parse", "--path-format=absolute", "--git-path", "index" })
	local tmp = os.tmpname()
	os.remove(tmp)
	-- Starting from a copy of the real index lets git reuse its stat cache
	if index and vim.uv.fs_stat(index) then
		vim.uv.fs_copyfile(index, tmp)
	end
	local env = { GIT_INDEX_FILE = tmp }
	local tree = M.git(root, { "add", "-A" }, env) and M.git(root, { "write-tree" }, env)
	os.remove(tmp)
	return tree
end

local function commit(root, tree, parent, message)
	local args = { "commit-tree", tree, "-m", message }
	if parent then
		vim.list_extend(args, { "-p", parent })
	end
	return M.git(root, args, identity)
end

local function first_line(text)
	local line = vim.trim((text or ""):match("^%s*([^\n]*)") or "")
	if #line > 72 then
		line = line:sub(1, 71) .. "…"
	end
	return line ~= "" and line or "(no prompt)"
end

--- Close the session's open turn: snapshot the end state and record it when
--- anything changed. Returns { id, start, files } or nil.
function M.finish(root, session)
	local ref = START_REF .. session
	local start = M.git(root, { "rev-parse", "--verify", "-q", ref })
	if not start then
		return nil
	end
	M.git(root, { "update-ref", "-d", ref })
	local tree = M.tree(root)
	if not tree or tree == M.git(root, { "rev-parse", start .. "^{tree}" }) then
		return nil
	end
	local subject = M.git(root, { "log", "-1", "--format=%s", start }) or "(no prompt)"
	local id = commit(root, tree, start, subject)
	if not id then
		return nil
	end
	M.git(root, { "update-ref", "--create-reflog", "-m", subject, M.ref, id })
	local files = M.git(root, { "diff", "--name-only", "--no-renames", start, id })
	return { id = id, start = start, files = files and vim.split(files, "\n", { trimempty = true }) or {} }
end

--- Open a turn for the session: snapshot the state the agent starts from.
--- A turn left open (interrupted, no Stop) is closed first so its edits don't
--- vanish into the next turn's baseline.
function M.start(root, session, prompt)
	M.finish(root, session)
	local tree = M.tree(root)
	if not tree then
		return
	end
	local head = M.git(root, { "rev-parse", "--verify", "-q", "HEAD" })
	local id = commit(root, tree, head, first_line(prompt) .. "\n\n" .. (prompt or ""))
	if id then
		M.git(root, { "update-ref", START_REF .. session, id })
	end
end

--- Recorded turns, newest first: { id, start, time, subject, stat }
function M.list(root, limit)
	local out = M.git(root, {
		"log",
		"-g",
		"--no-renames",
		"--shortstat",
		"-n",
		tostring(limit or 50),
		"--format=%x1e%H%x09%P%x09%ct%x09%gs",
		M.ref,
	})
	local turns = {}
	for record in (out or ""):gmatch("\30([^\30]+)") do
		local head, stat = record:match("^([^\n]*)\n?(.*)$")
		local id, start, time, subject = head:match("^(%x+)\t(%x*)\t(%d+)\t(.*)$")
		if id and start ~= "" then
			table.insert(turns, {
				id = id,
				start = start,
				time = tonumber(time),
				subject = subject,
				stat = vim.trim(stat or ""),
			})
		end
	end
	return turns
end

-- ── editor side ───────────────────────────────────────────────────────────────

local function ago(time)
	local s = os.time() - time
	if s < 60 then
		return s .. "s ago"
	elseif s < 3600 then
		return math.floor(s / 60) .. "m ago"
	elseif s < 86400 then
		return math.floor(s / 3600) .. "h ago"
	end
	return os.date("%b %d", time)
end

local function current_root()
	local root = M.root()
	if not root then
		vim.notify("Not in a git repository", vim.log.levels.WARN)
	end
	return root
end

local function latest(root)
	local turn = M.list(root, 1)[1]
	if not turn then
		vim.notify("No agent turns recorded yet (see scripts/agent-hook.lua)", vim.log.levels.WARN)
	end
	return turn
end

--- CodeDiff of one turn: start snapshot vs end snapshot (read-only; edit the
--- file itself via <leader>gd). Snapshot-vs-snapshot is what keeps new and
--- untracked files right; diffing a snapshot against the working tree can't.
function M.review(turn)
	require("core.review").toggle(turn.start .. " " .. turn.id)
end

function M.review_last()
	local root = current_root()
	local turn = root and latest(root)
	if turn then
		M.review(turn)
	end
end

--- Put the files a turn changed back to how the turn found them. Only the
--- working tree is touched; the index (review state) is left alone.
function M.undo(turn, root)
	root = root or current_root()
	if not root then
		return
	end
	local out = M.git(root, { "diff", "--name-status", "--no-renames", turn.start, turn.id })
	local restore, remove, files = {}, {}, {}
	for line in (out or ""):gmatch("[^\n]+") do
		local status, path = line:match("^(%a)%d*\t(.+)$")
		if path then
			table.insert(files, path)
			table.insert(status == "A" and remove or restore, path)
		end
	end
	if #files == 0 then
		vim.notify("That turn changed nothing", vim.log.levels.WARN)
		return
	end

	for _, path in ipairs(files) do
		local buf = vim.fn.bufnr(root .. "/" .. path)
		if buf ~= -1 and vim.bo[buf].modified then
			vim.notify("Unsaved changes in " .. path .. "; write or discard them first", vim.log.levels.ERROR)
			return
		end
	end

	-- Anything edited after the turn ended would be lost too: ask first
	local now = M.tree(root)
	local drift = now and M.git(root, vim.list_extend({ "diff", "--name-only", turn.id, now, "--" }, files)) or ""
	if drift ~= "" then
		local changed = vim.split(drift, "\n", { trimempty = true })
		local choice = vim.fn.confirm(
			("%d of these files changed after the turn:\n%s\n\nRevert anyway? Those later edits are lost too."):format(
				#changed,
				table.concat(changed, "\n")
			),
			"&Revert\n&Cancel",
			2
		)
		if choice ~= 1 then
			return
		end
	end

	if #restore > 0 then
		local ok, err = M.git(root, vim.list_extend({ "restore", "--source=" .. turn.start, "--worktree", "--" }, restore))
		if not ok then
			vim.notify("git restore failed: " .. err, vim.log.levels.ERROR)
			return
		end
	end
	for _, path in ipairs(remove) do
		os.remove(root .. "/" .. path)
		local buf = vim.fn.bufnr(root .. "/" .. path)
		if buf ~= -1 then
			pcall(require("mini.bufremove").delete, buf, true)
		end
	end
	vim.cmd("checktime")
	vim.notify(("Reverted turn \"%s\" (%d files)"):format(turn.subject, #files))

	-- Tell the agent, or it will happily redo it
	vim.ui.input({ prompt = "Why? (queued for the agent; empty = no reason) " }, function(reason)
		if reason == nil then
			return
		end
		local text = ("I reverted your turn \"%s\"; these files are back to how they were before it: %s."):format(
			turn.subject,
			table.concat(files, ", ")
		)
		if vim.trim(reason) ~= "" then
			text = text .. " Reason: " .. vim.trim(reason)
		end
		require("core.comments").add_general(text)
	end)
end

function M.undo_last()
	local root = current_root()
	local turn = root and latest(root)
	if turn and vim.fn.confirm(("Revert agent turn \"%s\"?\n%s"):format(turn.subject, turn.stat), "&Revert\n&Cancel", 2) == 1 then
		M.undo(turn, root)
	end
end

--- Telescope over recorded turns: <CR> review, <C-x> revert
function M.pick()
	local root = current_root()
	if not root then
		return
	end
	local turns = M.list(root)
	if #turns == 0 then
		latest(root)
		return
	end
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local conf = require("telescope.config").values

	pickers
		.new({}, {
			prompt_title = "Agent Turns  <CR> review · <C-x> revert",
			finder = finders.new_table({
				results = turns,
				entry_maker = function(turn)
					local files = turn.stat:match("^(%d+) files? changed") or "0"
					return {
						value = turn,
						display = ("%-8s %3s files  %s"):format(ago(turn.time), files, turn.subject),
						ordinal = turn.subject,
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					local t = entry.value
					return {
						"sh",
						"-c",
						'git -C "$0" --no-pager diff --stat --color=always "$1" "$2"; echo; git -C "$0" --no-pager diff --color=always "$1" "$2"',
						root,
						t.start,
						t.id,
					}
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if entry then
						M.review(entry.value)
					end
				end)
				map({ "i", "n" }, "<C-x>", function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if entry then
						M.undo(entry.value, root)
					end
				end)
				return true
			end,
		})
		:find()
end

return M
