return {
	{ "tpope/vim-sleuth" },
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		dependencies = { "hrsh7th/nvim-cmp" },
		config = function()
			require("nvim-autopairs").setup({})
			local cmp_autopairs = require("nvim-autopairs.completion.cmp")
			local cmp = require("cmp")
			cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
		end,
	},
	{
		"echasnovski/mini.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
		config = function()
			local ai = require("mini.ai")
			ai.setup({
				n_lines = 500,
				-- Tree-sitter definitions (queries from nvim-treesitter-textobjects);
				-- `f` stays mini.ai's function call. vaF<leader>as sends a whole function.
				custom_textobjects = {
					F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
					c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
				},
			})

			require("mini.surround").setup({
				-- gz prefix avoids conflict with flash.nvim
				mappings = {
					add = "gza",
					delete = "gzd",
					find = "gzf",
					find_left = "gzF",
					highlight = "gzh",
					replace = "gzr",
					update_n_lines = "gzn",
				},
			})

			require("mini.bufremove").setup()
		end,
	},
	{
		-- `main` is the branch for Neovim 0.12+ (`master` is archived and breaks on 0.12).
		-- Highlighting is Neovim's own; this plugin installs parsers/queries and provides indent.
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false, -- main does not support lazy-loading
		build = ":TSUpdate",
		config = function()
			local ts = require("nvim-treesitter")
			-- A clone left on the old `master` branch (lazy doesn't switch branches on
			-- its own) has no install(): say how to fix it instead of erroring
			if not ts.install then
				vim.notify(
					"nvim-treesitter is on its old `master` branch. Run :Lazy sync, then restart.",
					vim.log.levels.WARN
				)
				return
			end
			ts.install({
				"bash",
				"c",
				"diff",
				"html",
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"query",
				"vim",
				"vimdoc",
				"python",
				"go",
				"java",
				"javascript",
				"typescript",
				"tsx",
				"json",
				"css",
				"jsdoc",
				"regex",
				"rust",
				"cpp",
				"yaml",
				"toml",
			})

			local function enable(buf, lang)
				if not pcall(vim.treesitter.start, buf, lang) then
					return false
				end
				vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				return true
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
				callback = function(ev)
					local lang = vim.treesitter.language.get_lang(ev.match)
					if not lang or enable(ev.buf, lang) then
						return
					end
					-- auto-install: fetch a missing parser once, then start highlighting
					if vim.tbl_contains(ts.get_available(), lang) then
						ts.install(lang):await(function()
							vim.schedule(function()
								if vim.api.nvim_buf_is_valid(ev.buf) then
									enable(ev.buf, lang)
								end
							end)
						end)
					end
				end,
			})
		end,
	},
	{
		-- Jump by function/class when skimming long agent-written files.
		-- Selection (aF/ac) goes through mini.ai above.
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		event = "VeryLazy",
		init = function()
			-- Filetype plugins (python, rust, go, ...) would shadow ]m/[m buffer-locally
			vim.g.no_plugin_maps = true
		end,
		config = function()
			require("nvim-treesitter-textobjects").setup({ move = { set_jumps = true } })
			local move = require("nvim-treesitter-textobjects.move")
			local function map(lhs, fn, query, desc)
				vim.keymap.set({ "n", "x", "o" }, lhs, function()
					move[fn](query, "textobjects")
				end, { desc = desc })
			end
			map("]m", "goto_next_start", "@function.outer", "Next function")
			map("[m", "goto_previous_start", "@function.outer", "Previous function")
			map("]M", "goto_next_end", "@function.outer", "Next function end")
			map("[M", "goto_previous_end", "@function.outer", "Previous function end")
			map("]k", "goto_next_start", "@class.outer", "Next class")
			map("[k", "goto_previous_start", "@class.outer", "Previous class")
		end,
	},
	{
		"windwp/nvim-ts-autotag",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			opts = {
				enable = true,
				enable_close = true,
				enable_rename = true,
				enable_close_on_slash = false,
			},
		},
		config = function(_, opts)
			require("nvim-ts-autotag").setup(opts)

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "javascriptreact", "typescriptreact", "javascript", "typescript" },
				callback = function()
					vim.keymap.set("i", "/", function()
						local line = vim.api.nvim_get_current_line()
						local col = vim.api.nvim_win_get_cursor(0)[2]
						local before_cursor = line:sub(1, col)
						local component = before_cursor:match("<([A-Z][%w_%.%-]*)$")
							or before_cursor:match("<([A-Z][%w_%.%-]*)%s+[^>]*$")
						if component then
							return " />"
						end
						return "/"
					end, { buffer = true, expr = true })
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		event = "BufReadPost",
		opts = {
			enable = true,
			multiwindow = false,
			max_lines = 3,
			min_window_height = 0,
			line_numbers = true,
			multiline_threshold = 20,
			trim_scope = "outer",
			mode = "cursor",
			separator = nil,
			zindex = 20,
		},
	},
	{
		"Wansmer/treesj",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		keys = {
			{ "gj", "<cmd>TSJToggle<cr>", desc = "Toggle split/join" },
			{ "gJ", "<cmd>TSJJoin<cr>", desc = "Join lines" },
			{ "gS", "<cmd>TSJSplit<cr>", desc = "Split lines" },
		},
		opts = {
			use_default_keymaps = false,
			max_join_length = 250,
		},
	},
	{
		"folke/ts-comments.nvim",
		event = "VeryLazy",
		opts = {},
	},
}
