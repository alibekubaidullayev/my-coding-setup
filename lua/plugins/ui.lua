-- Editor chrome: statusline, winbar, cmdline/messages, notifications,
-- indent guides, cursor effects and other eye candy.

-- Filetypes where decorative UI (indent guides, scrollbar, mode tint) stays off
local plain_fts = {
	"alpha",
	"help",
	"lazy",
	"mason",
	"notify",
	"oil",
	"Trouble",
	"trouble",
	"TelescopePrompt",
	"TelescopeResults",
	"dapui_scopes",
	"dapui_breakpoints",
	"dapui_stacks",
	"dapui_watches",
	"dapui_console",
	"dap-repl",
	"neotest-summary",
	"neotest-output-panel",
	"grug-far",
	"no-neck-pain",
	"codediff-explorer",
	"codediff-history",
	"codediff-help",
}

return {
	{
		"rcarriga/nvim-notify",
		lazy = false,
		opts = {
			timeout = 3000,
			stages = "fade_in_slide_out",
			render = "wrapped-compact",
			max_width = 60,
			top_down = true,
			fps = 60,
			background_colour = "#101010",
		},
		config = function(_, opts)
			local notify = require("notify")
			notify.setup(opts)
			vim.notify = notify
		end,
	},

	-- Floating cmdline, prettier messages and LSP docs
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
		opts = {
			cmdline = {
				view = "cmdline_popup",
				format = {
					cmdline = { icon = "\u{f120}" },
					search_down = { icon = "\u{f002} \u{f063}" },
					search_up = { icon = "\u{f002} \u{f062}" },
					lua = { icon = "\u{e620}" },
					help = { icon = "\u{f059}" },
				},
			},
			lsp = {
				-- fidget.nvim already shows LSP progress
				progress = { enabled = false },
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			presets = {
				bottom_search = false,
				command_palette = true,
				long_message_to_split = true,
				lsp_doc_border = true,
			},
			routes = {
				-- Hide "written" / undo chatter
				{
					filter = {
						event = "msg_show",
						any = {
							{ find = "%d+L, %d+B" },
							{ find = "; after #%d+" },
							{ find = "; before #%d+" },
							{ find = "%d fewer lines" },
							{ find = "%d more lines" },
						},
					},
					opts = { skip = true },
				},
			},
		},
		keys = {
			{ "<leader>sN", "<cmd>Noice telescope<cr>", desc = "Noice Messages" },
		},
	},

	-- Statusline
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		init = function()
			-- Keep an empty statusline until lualine loads (avoids a flash of the default one)
			vim.g.lualine_laststatus = vim.o.laststatus
			if vim.fn.argc(-1) > 0 then
				vim.o.statusline = " "
			else
				vim.o.laststatus = 0
			end
		end,
		config = function()
			vim.o.laststatus = vim.g.lualine_laststatus

			local function recording()
				local reg = vim.fn.reg_recording()
				return reg ~= "" and ("\u{f04b7} @" .. reg) or ""
			end

			local function lsp_clients()
				local names = {}
				for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
					table.insert(names, c.name)
				end
				return #names > 0 and ("\u{f085} " .. table.concat(names, " ")) or ""
			end

			local function harpoon_mark()
				local ok, harpoon = pcall(require, "harpoon")
				if not ok then
					return ""
				end
				local current = vim.fn.expand("%:p:.")
				for i, item in ipairs(harpoon:list().items) do
					if item.value == current then
						return "\u{f06e1} " .. i
					end
				end
				return ""
			end

			local function lualine_theme()
				local ll = require("core.lackluster")
				return ll.is_active() and ll.lualine() or "auto"
			end

			local config = {
				options = {
					theme = lualine_theme(),
					globalstatus = true,
					component_separators = "",
					section_separators = { left = "\u{e0b4}", right = "\u{e0b6}" },
					disabled_filetypes = { statusline = { "alpha" } },
				},
				sections = {
					lualine_a = {
						{
							"mode",
							icon = "\u{e62b}",
							separator = { left = "\u{e0b6}", right = "\u{e0b4}" },
							padding = { left = 0, right = 1 },
						},
					},
					lualine_b = {
						{ "branch", icon = "\u{e725}" },
						{
							"diff",
							symbols = { added = "\u{f457} ", modified = "\u{f459} ", removed = "\u{f458} " },
						},
					},
					lualine_c = {
						{ "filetype", icon_only = true, separator = "", padding = { left = 2, right = 0 } },
						{
							"filename",
							path = 1,
							symbols = { modified = "\u{f111}", readonly = "\u{f023}", unnamed = "", newfile = "\u{f067}" },
						},
						{ harpoon_mark, color = "Special" },
						{
							"diagnostics",
							symbols = { error = "\u{f0159} ", warn = "\u{f0028} ", info = "\u{f02fd} ", hint = "\u{f0336} " },
						},
					},
					lualine_x = {
						{ recording, color = "DiagnosticError" },
						{
							function()
								return require("noice").api.status.search.get()
							end,
							cond = function()
								return package.loaded["noice"] and require("noice").api.status.search.has()
							end,
							color = "Special",
						},
						{
							require("lazy.status").updates,
							cond = require("lazy.status").has_updates,
							color = "Comment",
						},
						{ lsp_clients, color = "Comment" },
					},
					lualine_y = {
						{ "progress", separator = " ", padding = { left = 1, right = 0 } },
					},
					lualine_z = {
						{
							"location",
							separator = { left = "\u{e0b6}", right = "\u{e0b4}" },
							padding = { left = 1, right = 0 },
						},
					},
				},
				extensions = { "lazy", "man", "mason", "nvim-dap-ui", "oil", "quickfix", "trouble" },
			}
			require("lualine").setup(config)

			-- lackluster uses a custom table theme, so re-pick it when the scheme changes
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = vim.api.nvim_create_augroup("lualine-theme", { clear = true }),
				callback = function()
					config.options.theme = lualine_theme()
					require("lualine").setup(config)
				end,
			})
		end,
	},

	-- Breadcrumbs in the winbar
	{
		"Bekaboo/dropbar.nvim",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = { "nvim-telescope/telescope-fzf-native.nvim" },
		keys = {
			{ "<leader>;", function() require("dropbar.api").pick() end, desc = "Pick Breadcrumb" },
		},
		opts = {},
	},

	-- Scrollbar with diagnostics / git / search marks
	{
		"lewis6991/satellite.nvim",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			current_only = false,
			winblend = 0,
			excluded_filetypes = plain_fts,
		},
	},

	-- Brackets coloured by nesting depth
	{
		"HiPhish/rainbow-delimiters.nvim",
		event = { "BufReadPost", "BufNewFile" },
	},
	-- Quiet indent guides (no current-scope highlight)
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			indent = { char = "\u{258f}", tab_char = "\u{258f}" },
			scope = { enabled = false },
			exclude = { filetypes = plain_fts },
		},
	},

	-- Cursorline / line number tinted by the current mode
	{
		"mvllow/modes.nvim",
		event = "VeryLazy",
		opts = function()
			local ll = require("core.lackluster")
			return {
				colors = ll.is_active() and ll.modes or {},
				line_opacity = 0.18,
				set_cursor = false,
				set_cursorline = true,
				set_number = true,
				ignore = plain_fts,
			}
		end,
	},

	-- Inline colour swatches for #hex / rgb() / tailwind classes
	{
		"brenoprata10/nvim-highlight-colors",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			render = "virtual",
			virtual_symbol = "\u{25a0}",
			virtual_symbol_position = "inline",
			enable_tailwind = true,
		},
		keys = {
			{ "<leader>uH", "<cmd>HighlightColors Toggle<cr>", desc = "Toggle Color Highlights" },
		},
	},

	-- Markdown rendered in the buffer (headings, tables, checkboxes, code blocks)
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
		opts = {
			code = { sign = false, width = "block", right_pad = 2, border = "thin" },
			heading = { sign = false, width = "block", left_pad = 1, right_pad = 2 },
		},
		keys = {
			{ "<leader>um", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle Markdown Render" },
		},
	},

	{
		"shortcuts/no-neck-pain.nvim",
		version = "*",
		keys = {
			{ "<leader>uz", "<cmd>NoNeckPain<cr>", desc = "Toggle Center Buffer" },
		},
		opts = {
			width = 120,
			minSideBufferWidth = 10,
		},
	},

	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			preset = "helix",
			delay = 250,
			icons = { mappings = true, rules = false },
			spec = {
				{ "<leader>b", group = "Buffer", icon = "\u{f0c5}" },
				{ "<leader>c", group = "Code / Build", icon = "\u{f121}" },
				{ "<leader>r", group = "Rename", icon = "\u{f044}" },
				{ "<leader>s", group = "Search", icon = "\u{f002}" },
				{ "<leader>t", group = "Test", icon = "\u{f0668}" },
				{ "<leader>D", group = "Debug", icon = "\u{f188}" },
				{ "<leader>h", group = "Git Hunk", icon = "\u{f1d3}", mode = { "n", "v" } },
				{ "<leader>g", group = "Git", icon = "\u{e702}" },
				{ "<leader>q", group = "Session", icon = "\u{f0c7}" },
				{ "<leader>u", group = "UI Toggles", icon = "\u{f1fc}" },
				{ "<leader>x", group = "Diagnostics", icon = "\u{f188}" },
			},
		},
	},
}
