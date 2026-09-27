return {
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = {
			library = { {
				path = "luvit-meta/library",
				words = { "vim%.uv" },
			} },
		},
	},
	{
		"Bilal2453/luvit-meta",
		lazy = true,
	},
	{

		"neovim/nvim-lspconfig",
		dependencies = {
			{
				"williamboman/mason.nvim",
				config = true,
			},
			"williamboman/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			{
				"j-hui/fidget.nvim",
				opts = {
					progress = {
						display = {
							done_icon = "\u{f00c}",
							progress_icon = { pattern = "dots", period = 1 },
						},
					},
					notification = {
						window = { winblend = 0, border = "none" },
					},
				},
			},
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			-- Nicer diagnostics UI
			vim.diagnostic.config({
				severity_sort = true,
				underline = true,
				update_in_insert = false,
				float = { border = "rounded", source = "if_many" },
				-- Inline messages are drawn by tiny-inline-diagnostic (plugins/diag.lua)
				virtual_text = false,
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
					-- Tint the line number too, so problems stand out in the gutter
					numhl = {
						[vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
						[vim.diagnostic.severity.WARN] = "DiagnosticSignWarn",
						[vim.diagnostic.severity.INFO] = "DiagnosticSignInfo",
						[vim.diagnostic.severity.HINT] = "DiagnosticSignHint",
					},
				} or {},
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", {
					clear = true,
				}),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						mode = mode or "n"
						vim.keymap.set(mode, keys, func, {
							buffer = event.buf,
							desc = "LSP: " .. desc,
						})
					end

					-- Navigation/rename/code-action maps live in plugins/nav.lua

					local client = vim.lsp.get_client_by_id(event.data.client_id)
					-- Reference highlighting under the cursor comes from vim-illuminate (plugins/nav.lua)

					-- Inlay hints toggle at <leader>uh (core/keymaps.lua)

					if client and (client.name == "tsserver" or client.name == "ts_ls") then
						local ts_augroup = vim.api.nvim_create_augroup("kickstart-lsp-ts-" .. event.buf, {
							clear = true,
						})

						vim.api.nvim_create_autocmd("BufWritePre", {
							buffer = event.buf,
							group = ts_augroup,
							desc = "LSP: Organize TS/JS imports before save",
							callback = function()
								-- Leave agent-written imports alone while reviewing (core/review.lua)
								if require("core.review").is_reviewing(event.buf) then
									return
								end
								local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
								params.context = { only = { "source.organizeImports" } }
								local result =
									vim.lsp.buf_request_sync(event.buf, "textDocument/codeAction", params, 300) -- reduced from 1000

								for _, res in pairs(result or {}) do
									for _, r in ipairs(res.result or {}) do
										if r.edit then
											vim.lsp.util.apply_workspace_edit(r.edit, client.offset_encoding)
										end
										if r.command then
											local command = r
											if type(r.command) == "table" then
												command = r.command
											end
											-- vim.lsp.buf.execute_command() is deprecated since nvim 0.11
											client:exec_cmd(command, { bufnr = event.buf })
										end
									end
								end
							end,
						})

						map("<leader>co", function()
							vim.lsp.buf.code_action({
								context = { only = { "source.organizeImports" } },
								apply = true,
							})
						end, "[C]ode Organize Imports")
					end
				end,
			})

			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities = vim.tbl_deep_extend("force", capabilities, require("cmp_nvim_lsp").default_capabilities())
			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							completion = {
								callSnippet = "Replace",
							},
						},
					},
				},
				pyright = {
					settings = {
						pyright = {
							disableOrganizeImports = true,
						},
						python = {
							analysis = {
								extraPaths = { "./app" },
							},
						},
					},
				},
				ruff = {
					init_options = {
						settings = {
							--         fixAll = true
							target_version = "py313",
						},
					},
				},
				gopls = {
					-- gopls options must live under settings.gopls, otherwise they are ignored
					settings = {
						gopls = {
							analyses = {
								unusedparams = true,
							},
							staticcheck = true,
							gofumpt = true,
						},
					},
				},
				clangd = {
					cmd = {
						"clangd",
						"--background-index",
						"--clang-tidy",
						"--header-insertion=iwyu",
						"--completion-style=detailed",
						"--function-arg-placeholders",
					},
					capabilities = capabilities,
					filetypes = { "c", "cpp", "objc", "objcpp" },
					settings = {
						clangd = {
							completion = {
								autoimport = true,
							},
							fallbackFlags = { "-std=c++20" },
						},
					},
				},
				rust_analyzer = {
					settings = {
						["rust-analyzer"] = {
							check = {
								command = "clippy",
							},
							diagnostics = {
								enable = true,
								experimental = { enable = true },
							},
							inlayHints = {
								bindingModeHints = { enable = true },
								chainingHints = { enable = true },
								closureReturnTypeHints = { enable = "always" },
								lifetimeElisionHints = { enable = "always" },
								reborrowHints = { enable = "always" },
							},
							completion = {
								autoimport = { enable = true },
							},
							procMacro = { enable = true },
							cargo = {
								allFeatures = true,
							},
						},
					},
				},
				neocmake = {},
				ts_ls = {
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
						javascript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
				},
				eslint = {
					settings = {
						workingDirectories = { mode = "auto" },
					},
				},
			}

			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "\u{f00c}",
						package_pending = "\u{f110}",
						package_uninstalled = "\u{f00d}",
					},
				},
			})

			-- Translate lspconfig server names -> Mason package names.
			-- mason-lspconfig v2 removed the old `mappings.server` module; use the public API.
			local ok_mappings, lspconfig_to_package = pcall(function()
				return require("mason-lspconfig").get_mappings().lspconfig_to_package
			end)

			local ensure_installed = {}
			local function want(package)
				if package and not vim.tbl_contains(ensure_installed, package) then
					table.insert(ensure_installed, package)
				end
			end

			for server_name in pairs(servers) do
				if ok_mappings then
					want(lspconfig_to_package[server_name] or server_name)
				elseif server_name ~= "ts_ls" and server_name ~= "eslint" then
					-- Without the mapping API these two names don't match their packages
					want(server_name)
				end
			end
			want("typescript-language-server")
			want("eslint-lsp")

			-- Formatters driven by conform.nvim (defined below in this file).
			-- rustfmt is intentionally absent: it ships with rustup.
			for _, tool in ipairs({
				"stylua",
				"gofumpt",
				"goimports",
				"clang-format",
				"cmakelang",
				"google-java-format",
				"jdtls",
				"prettierd",
				"prettier",
			}) do
				want(tool)
			end

			require("mason-tool-installer").setup({
				ensure_installed = ensure_installed,
			})

			-- mason-lspconfig v2 removed the `handlers` option: it now simply calls
			-- `vim.lsp.enable()` for every installed server. Per-server configuration
			-- must be registered via `vim.lsp.config()` (this extends the defaults
			-- shipped by nvim-lspconfig in its lsp/ directory).
			vim.lsp.config("*", { capabilities = capabilities })
			for server_name, config in pairs(servers) do
				vim.lsp.config(server_name, config)
			end

			require("mason-lspconfig").setup({
				-- stylua is installed as a formatter for conform; don't also start it as an LSP
				automatic_enable = { exclude = { "stylua" } },
			})
		end,
	},
	-- {
	-- 	"mfussenegger/nvim-jdtls",
	-- 	ft = "java", -- Enable only on .java file extensions
	-- },
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				build = (function()
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
						return
					end
					return "make install_jsregexp"
				end)(),
				dependencies = {
					"rafamadriz/friendly-snippets",
				},
			},
			"saadparwaiz1/cmp_luasnip",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-path",
			"onsails/lspkind.nvim",
		},
		config = function()
			local cmp = require("cmp")
			local lspkind = require("lspkind")
			local luasnip = require("luasnip")
			luasnip.config.setup({})
			require("luasnip.loaders.from_vscode").lazy_load()

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				completion = {
					completeopt = "menu,menuone,noinsert",
				},
				window = {
					completion = cmp.config.window.bordered({
						winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel,Search:None",
						col_offset = -3,
						side_padding = 0,
					}),
					documentation = cmp.config.window.bordered({
						winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
						max_width = 80,
						max_height = 20,
					}),
				},
				-- Kind icon in its own column on the left, kind name dimmed on the right
				formatting = {
					fields = { "kind", "abbr", "menu" },
					format = function(entry, vim_item)
						local kind = vim_item.kind or ""
						vim_item.kind = " " .. (lspkind.symbol_map[kind] or "\u{f0c8}") .. " "

						-- Keep the completion menu narrow so docs have room beside it.
						local max_abbr, max_menu = 40, 30
						if vim_item.abbr and vim.fn.strdisplaywidth(vim_item.abbr) > max_abbr then
							vim_item.abbr = vim.fn.strcharpart(vim_item.abbr, 0, max_abbr - 1) .. "…"
						end
						local menu = vim_item.menu
						if not menu or menu == "" then
							menu = entry.source.name == "nvim_lsp" and kind or entry.source.name
						end
						if vim.fn.strdisplaywidth(menu) > max_menu then
							menu = vim.fn.strcharpart(menu, 0, max_menu - 1) .. "…"
						end
						vim_item.menu = "  " .. menu
						return vim_item
					end,
				},
				experimental = {
					ghost_text = { hl_group = "CmpGhostText" },
				},
				mapping = cmp.mapping.preset.insert({
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<Tab>"] = cmp.mapping.confirm({
						select = true,
					}),
					["<C-Space>"] = cmp.mapping.complete({}),
					["<C-l>"] = cmp.mapping(function()
						if luasnip.expand_or_locally_jumpable() then
							luasnip.expand_or_jump()
						end
					end, { "i", "s" }),
					["<C-h>"] = cmp.mapping(function()
						if luasnip.locally_jumpable(-1) then
							luasnip.jump(-1)
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "lazydev", group_index = 0 },
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "path" },
				},
			})
		end,
	},
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>f",
				function()
					require("conform").format({
						async = true,
						lsp_format = "fallback",
					})
				end,
				mode = "",
				desc = "[F]ormat buffer",
			},
		},
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				-- Keep a one-line fix during review from reformatting the agent's whole
				-- file into the diff. <leader>f still formats on demand.
				if require("core.review").is_reviewing(bufnr) then
					return
				end
				local disable_filetypes = {
					c = true,
					cpp = true,
				}
				local lsp_format_opt
				if disable_filetypes[vim.bo[bufnr].filetype] then
					lsp_format_opt = "never"
				else
					lsp_format_opt = "fallback"
				end
				return {
					timeout_ms = 500,
					lsp_format = lsp_format_opt,
				}
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
				go = { "gofumpt", "goimports" },
				c = { "clang_format" },
				cpp = { "clang_format" },
				cmake = { "cmake_format" },
				rust = { "rustfmt" },
				java = { "google-java-format" },
				javascript = {},
				javascriptreact = {},
				typescript = {},
				typescriptreact = {},
			},
			formatters = {
				clang_format = {
					prepend_args = { "--style=file", "--fallback-style=LLVM" },
				},
			},
		},
	},
}
