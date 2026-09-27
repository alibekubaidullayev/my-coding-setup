-- Colorschemes. lackluster-mint is the default; the others are lazy-loaded and
-- available from <leader>uC. Whatever you pick is remembered across restarts.
local theme = require("core.theme")

return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		lazy = true,
		opts = {
			flavour = "mocha",
			term_colors = true,
			-- Borderless "solid" floats with coloured title badges (Telescope, oil, hover docs…)
			float = { solid = true },
			styles = {
				comments = { "italic" },
				conditionals = { "italic" },
				keywords = { "italic" },
				types = { "bold" },
			},
			lsp_styles = {
				underlines = {
					errors = { "undercurl" },
					hints = { "undercurl" },
					warnings = { "undercurl" },
					information = { "undercurl" },
				},
				inlay_hints = { background = true },
			},
			-- Integrations for installed plugins are enabled automatically via lazy.nvim
			auto_integrations = true,
			integrations = {
				dropbar = { enabled = true, color_mode = true },
				illuminate = { enabled = true, lsp = false },
				indent_blankline = { enabled = true, colored_indent_levels = false },
			},
			custom_highlights = function(c)
				return {
					WinSeparator = { fg = c.surface1 },
					CursorLineNr = { fg = c.lavender, style = { "bold" } },
					LineNr = { fg = c.surface1 },
					Folded = { fg = c.blue, bg = c.surface0 },
					CmpGhostText = { fg = c.overlay0, style = { "italic" } },
					LspInlayHint = { fg = c.overlay0, bg = c.mantle, style = { "italic" } },
					TreesitterContextBottom = { sp = c.surface1, style = { "underline" } },
				}
			end,
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
		end,
	},
	{
		"folke/tokyonight.nvim",
		lazy = true,
		opts = { style = "night", styles = { keywords = { italic = true } }, lualine_bold = true },
	},
	{
		"rebelot/kanagawa.nvim",
		lazy = true,
		opts = { compile = false, dimInactive = false, colors = { theme = { all = { ui = { bg_gutter = "none" } } } } },
	},
	{
		"rose-pine/neovim",
		name = "rose-pine",
		lazy = true,
		opts = { styles = { italic = true } },
	},
	{
		"slugbyte/lackluster.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			-- extend lackluster to all UI plugins before the saved scheme is applied
			require("core.lackluster").setup()
			theme.apply_saved()
		end,
		keys = {
			{
				"<leader>uC",
				function()
					theme.pick()
				end,
				desc = "Colorschemes",
			},
		},
	},
}
