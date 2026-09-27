return {
	{
		"folke/trouble.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		cmd = "Trouble",
		keys = {
			-- Easy buffer diagnostics (same as <leader>xX). Native <C-w>d stays the cursor float.
			{ "gl", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
			{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics (Trouble)" },
			{ "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols (Trouble)" },
			{ "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP Definitions/References (Trouble)" },
			{ "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Location List (Trouble)" },
			{ "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix List (Trouble)" },
			{ "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "TODOs (Trouble)" },
		},
		opts = {
			focus = true,
			auto_preview = true,
			auto_refresh = true,
			modes = {
				symbols = {
					win = { position = "right" },
				},
			},
		},
	},
	-- Diagnostics rendered as pill-shaped messages next to the code
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "LspAttach",
		priority = 1000,
		opts = {
			preset = "modern",
			options = {
				show_source = { enabled = true, if_many = true },
				multilines = { enabled = true, always_show = false },
				show_all_diags_on_cursorline = true,
				throttle = 50,
			},
		},
		keys = {
			{
				"<leader>uD",
				function()
					require("tiny-inline-diagnostic").toggle()
				end,
				desc = "Toggle Inline Diagnostics",
			},
		},
	},
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			signs = false,
		},
	},
	{
		"MagicDuck/grug-far.nvim",
		cmd = "GrugFar",
		keys = {
			{
				"<leader>sR",
				function()
					require("grug-far").open({ transient = true })
				end,
				mode = { "n", "v" },
				desc = "[S]earch & [R]eplace (grug-far)",
			},
		},
		opts = {
			headerMaxWidth = 80,
		},
	},
}
