-- Reviewing agent changes (CodeDiff), file history, and per-directory sessions.
--
-- Review loop: <leader>gd opens the working tree vs index. Staged = reviewed:
-- accept with <leader>hs (hunk) or s/- (file), reject with <leader>hr, fix
-- things directly in the right pane. The agent's next round then shows up
-- alone under "Changes". <C-j>/<C-k> walk hunks across files, <C-S-j>/<C-S-k>
-- jump between files, gc folds unchanged code, t toggles side-by-side/inline,
-- <C-p> picks a file from the review, g? lists every key.
local function review(args)
	return function()
		require("core.review").toggle(args)
	end
end

return {
	{
		"esmuellert/codediff.nvim",
		cmd = "CodeDiff",
		keys = {
			{ "<leader>gd", review(), desc = "Review changes (toggle)" },
			{ "<leader>gD", review("--staged"), desc = "Review staged (approved) changes" },
			{ "<leader>gm", review("origin/HEAD..."), desc = "Review branch vs main" },
			{ "<leader>gh", "<cmd>CodeDiff history %<cr>", desc = "File history" },
			{ "<leader>gH", "<cmd>CodeDiff history<cr>", desc = "Repo history" },
			{ "<leader>gh", ":CodeDiff history<cr>", mode = "x", desc = "Selection history" },
			{ "<leader>gw", function() require("core.review").toggle_whitespace() end, desc = "Diff: toggle whitespace" },
		},
		opts = {
			diff = {
				-- Next hunk at the last one continues into the next file
				cycle_hunks_across_files = true,
			},
			keymaps = {
				view = {
					-- Hunk jumps replace window moves while in the review tab
					-- (buffer-local; <C-j>/<C-k> go back to windows once it closes)
					-- <C-j> (and <C-S-j>/<C-S-k> for files) are also mapped in
					-- core/review.lua: CodeDiff can't install those keys itself
					next_hunk = "<C-j>",
					prev_hunk = "<C-k>",
				},
			},
			explorer = {
				width = require("core.review").explorer_width,
				line_stats = { enabled = true, count_untracked = true },
			},
		},
	},
	{
		"folke/persistence.nvim",
		event = "BufReadPre",
		opts = {},
		keys = {
			{ "<leader>qs", function() require("persistence").load() end, desc = "Restore session (cwd)" },
			{ "<leader>qS", function() require("persistence").select() end, desc = "Pick session" },
			{ "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
			{ "<leader>qd", function() require("persistence").stop() end, desc = "Don't save this session" },
		},
	},
}
