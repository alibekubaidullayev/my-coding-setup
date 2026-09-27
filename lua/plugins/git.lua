return {
	"lewis6991/gitsigns.nvim",
	opts = {
		signs = {
			add = { text = "\u{258e}" },
			change = { text = "\u{258e}" },
			delete = { text = "\u{f0da}" },
			topdelete = { text = "\u{f0da}" },
			changedelete = { text = "\u{258e}" },
			untracked = { text = "\u{2506}" },
		},
		signs_staged = {
			add = { text = "\u{258e}" },
			change = { text = "\u{258e}" },
			delete = { text = "\u{f0da}" },
			topdelete = { text = "\u{f0da}" },
			changedelete = { text = "\u{258e}" },
		},
		current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
		current_line_blame_formatter = "   <author>, <author_time:%R> · <summary>",
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")
			local function map(mode, l, r, desc)
				vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
			end

			map("n", "]h", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]c", bang = true })
				else
					gitsigns.nav_hunk("next")
				end
			end, "Next git hunk")
			map("n", "[h", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[c", bang = true })
				else
					gitsigns.nav_hunk("prev")
				end
			end, "Previous git hunk")

			map("n", "<leader>hs", gitsigns.stage_hunk, "Stage hunk (toggle)")
			map("n", "<leader>hr", gitsigns.reset_hunk, "Reset hunk")
			map("v", "<leader>hs", function()
				gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Stage selected hunk")
			map("v", "<leader>hr", function()
				gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Reset selected hunk")
			map("n", "<leader>hS", gitsigns.stage_buffer, "Stage buffer")
			map("n", "<leader>hR", gitsigns.reset_buffer, "Reset buffer")
			map("n", "<leader>hp", gitsigns.preview_hunk, "Preview hunk")
			map("n", "<leader>hb", gitsigns.blame_line, "Blame line")
			map("n", "<leader>hd", gitsigns.diffthis, "Diff against index")
			map("n", "<leader>hB", gitsigns.toggle_current_line_blame, "Toggle line blame")
			-- Changes highlighted in place while editing outside the review tab
			map("n", "<leader>hi", function()
				gitsigns.toggle_linehl()
				gitsigns.toggle_word_diff()
			end, "Toggle inline diff highlight")
			map("n", "<leader>hq", function()
				gitsigns.setqflist("all")
			end, "All hunks to quickfix")
			-- vih<leader>as sends the hunk to the agent
			map({ "o", "x" }, "ih", gitsigns.select_hunk, "Inner hunk")
		end,
	},
}
