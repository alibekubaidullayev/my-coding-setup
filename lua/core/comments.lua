-- Review comments for the agent, batched like a PR review: comment on lines or
-- selections while going through a diff (they stay visible in the buffer),
-- reject hunks with a reason, then submit everything as one message together
-- with the prompt draft (core/prompt.lua). Works in plain buffers and in
-- CodeDiff's revision panes.
local M = {}

local ns = vim.api.nvim_create_namespace("agent-comments")

--- { key = buffer name, path, s, e, code, ft, text, general = bool }
M.items = {}

local function set_hl()
	vim.api.nvim_set_hl(0, "AgentComment", { default = true, link = "DiagnosticVirtualTextHint" })
	vim.api.nvim_set_hl(0, "AgentCommentSign", { default = true, link = "DiagnosticHint" })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("agent-comments-hl", { clear = true }),
	callback = set_hl,
})

function M.count()
	return #M.items
end

--- Where a buffer's lines live, for the agent: repo-relative path, plus a
--- note on the revision for CodeDiff's read-only panes
local function location(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name:match("^codediff://") then
		local ok, vf = pcall(require, "codediff.core.virtual_file")
		local parsed = ok and { vf.parse_url(name) } or {}
		local rev, path = parsed[2], parsed[3]
		if path then
			return path, rev and (rev:match("^:") and "staged version" or ("at " .. rev:sub(1, 10)))
		end
	end
	return require("core.agent").relpath(buf)
end

local function render(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local name = vim.api.nvim_buf_get_name(buf)
	local count = vim.api.nvim_buf_line_count(buf)
	for i, c in ipairs(M.items) do
		if c.key == name then
			local s, e = math.min(c.s, count), math.min(c.e, count)
			-- Sign over the range; the comment itself hangs under its last line
			c.mark = vim.api.nvim_buf_set_extmark(buf, ns, s - 1, 0, {
				end_row = e - 1,
				sign_text = "\u{f0188}",
				sign_hl_group = "AgentCommentSign",
			})
			vim.api.nvim_buf_set_extmark(buf, ns, e - 1, 0, {
				virt_lines = { { { ("   \u{f0188} %d: %s"):format(i, c.text), "AgentComment" } } },
			})
			c.buf = buf
		end
	end
end

local function render_all()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			render(buf)
		end
	end
	vim.cmd.redrawstatus()
end

--- Pick up line moves from edits before reading positions
local function sync()
	for _, c in ipairs(M.items) do
		if c.buf and c.mark and vim.api.nvim_buf_is_valid(c.buf) then
			local pos = vim.api.nvim_buf_get_extmark_by_id(c.buf, ns, c.mark, {})
			if pos[1] then
				c.s, c.e = pos[1] + 1, pos[1] + 1 + (c.e - c.s)
			end
		end
	end
end

local function range()
	if vim.fn.mode():match("^[vV\22]") then
		local s, e = vim.fn.line("v"), vim.fn.line(".")
		if s > e then
			s, e = e, s
		end
		vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
		return s, e
	end
	local l = vim.fn.line(".")
	return l, l
end

local function add(buf, s, e, text, code)
	local path, note = location(buf)
	table.insert(M.items, {
		key = vim.api.nvim_buf_get_name(buf),
		path = path,
		note = note,
		s = s,
		e = e,
		ft = vim.bo[buf].filetype,
		code = code or vim.api.nvim_buf_get_lines(buf, s - 1, e, false),
		text = text,
	})
	render_all()
end

--- Comment on the current line or selection
function M.add()
	local buf = vim.api.nvim_get_current_buf()
	local s, e = range()
	vim.ui.input({ prompt = "Comment for the agent: " }, function(text)
		if text and vim.trim(text) ~= "" then
			add(buf, s, e, vim.trim(text))
		end
	end)
end

--- A comment not tied to any line
function M.add_general(text)
	table.insert(M.items, { general = true, text = text })
	vim.cmd.redrawstatus()
	vim.notify("Queued for the agent (<leader>aS to send)")
end

--- Revert the hunk under the cursor (or the selected lines) and tell the
--- agent why, so it doesn't just put it back
function M.reject()
	local buf = vim.api.nvim_get_current_buf()
	local ok, gitsigns = pcall(require, "gitsigns")
	local hunks = ok and gitsigns.get_hunks(buf)
	if not hunks then
		vim.notify("No git hunks in this buffer", vim.log.levels.WARN)
		return
	end
	local visual = vim.fn.mode():match("^[vV\22]") ~= nil
	local s, e = range()

	local hunk
	for _, h in ipairs(hunks) do
		local hs = h.added.start
		local he = h.added.count > 0 and (hs + h.added.count - 1) or hs
		if s <= he and e >= hs then
			hunk = h
			break
		end
	end
	if not hunk then
		vim.notify("No changed lines here", vim.log.levels.WARN)
		return
	end
	if not visual then
		s = hunk.added.start
		e = hunk.added.count > 0 and (s + hunk.added.count - 1) or s
	end
	local code = visual and vim.api.nvim_buf_get_lines(buf, s - 1, e, false) or hunk.lines

	vim.ui.input({ prompt = "Reject — why? (empty = no reason) " }, function(reason)
		if reason == nil then
			return
		end
		local cb = function()
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("silent write")
					end)
				end
			end)
		end
		vim.api.nvim_buf_call(buf, function()
			gitsigns.reset_hunk(visual and { s, e } or nil, nil, cb)
		end)
		reason = vim.trim(reason)
		local text = "I reverted this change" .. (reason ~= "" and (": " .. reason) or ".")
		add(buf, s, s, text, code)
		M.items[#M.items].ft = visual and vim.bo[buf].filetype or "diff"
	end)
end

local function at_cursor()
	sync()
	local name = vim.api.nvim_buf_get_name(0)
	local l = vim.fn.line(".")
	for i = #M.items, 1, -1 do
		local c = M.items[i]
		if c.key == name and l >= c.s and l <= c.e then
			return i
		end
	end
end

function M.delete()
	local i = at_cursor()
	if not i then
		vim.notify("No comment on this line", vim.log.levels.WARN)
		return
	end
	table.remove(M.items, i)
	render_all()
end

function M.clear()
	M.items = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		end
	end
	vim.cmd.redrawstatus()
end

--- All comments in Trouble's quickfix view
function M.list()
	sync()
	if #M.items == 0 then
		vim.notify("No review comments")
		return
	end
	local qf = {}
	for i, c in ipairs(M.items) do
		local buf = c.key and vim.fn.bufnr(c.key)
		table.insert(qf, {
			bufnr = buf and buf ~= -1 and buf or nil,
			filename = c.key and not c.key:match("^codediff://") and c.key or nil,
			lnum = c.s or 1,
			end_lnum = c.e,
			text = ("%d: %s"):format(i, c.text),
		})
	end
	vim.fn.setqflist({}, " ", { title = "Agent review comments", items = qf })
	vim.cmd("Trouble qflist open")
end

local MAX_CODE = 30

--- The review as one message; nil when there's nothing to say
function M.format(draft)
	sync()
	local out = {}
	draft = vim.trim(draft or "")
	if draft ~= "" then
		table.insert(out, draft)
	end
	if #M.items > 0 then
		table.insert(out, (draft ~= "" and "Review comments" or "Review comments on your changes") .. ", please address each:")
		for i, c in ipairs(M.items) do
			if c.general then
				table.insert(out, ("%d. %s"):format(i, c.text))
			else
				local lines = c.s == c.e and tostring(c.s) or (c.s .. "-" .. c.e)
				local code = vim.list_slice(c.code, 1, MAX_CODE)
				if #c.code > MAX_CODE then
					table.insert(code, ("… (%d more lines)"):format(#c.code - MAX_CODE))
				end
				table.insert(out, table.concat({
					("%d. %s:%s%s"):format(i, c.path, lines, c.note and (" (" .. c.note .. ")") or ""),
					"```" .. (c.ft or ""),
					table.concat(code, "\n"),
					"```",
					c.text,
				}, "\n"))
			end
		end
	end
	return #out > 0 and table.concat(out, "\n\n") or nil
end

--- Send prompt draft + comments to the agent pane in one go
function M.submit()
	local prompt = require("core.prompt")
	local text = M.format(prompt.text())
	if not text then
		vim.notify("Nothing to send: no prompt draft or review comments", vim.log.levels.WARN)
		return
	end
	if require("core.agent").send(text) then
		prompt.clear()
		M.clear()
	else
		vim.notify("Draft and comments kept; <leader>aX clears them", vim.log.levels.WARN)
	end
end

local group = vim.api.nvim_create_augroup("agent-comments", { clear = true })
-- Comments follow their file into any window, and survive the file being reloaded
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
	group = group,
	callback = function(ev)
		if #M.items > 0 then
			render(ev.buf)
		end
	end,
})

return M
