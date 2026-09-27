-- Debugging + tests. DAP on F-keys / <leader>D; neotest under <leader>t.
return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			{
				"rcarriga/nvim-dap-ui",
				dependencies = { "nvim-neotest/nvim-nio" },
			},
			{
				"theHamsta/nvim-dap-virtual-text",
				opts = {
					commented = true,
				},
			},
			{
				"jay-babu/mason-nvim-dap.nvim",
				-- Repo string must match plugins/lsp.lua or lazy treats it as a second plugin
				dependencies = { "williamboman/mason.nvim" },
				opts = {
					automatic_installation = true,
					ensure_installed = {
						"codelldb",
						"debugpy",
						"delve",
						"js-debug-adapter",
					},
					handlers = {
						function(config)
							require("mason-nvim-dap").default_setup(config)
						end,
						-- codelldb and js-debug are configured by hand in nvim-dap's
						-- config below; default_setup would append its own launch
						-- configurations on top of ours.
						codelldb = function() end,
						js = function() end,
					},
				},
			},
		},
		keys = {
			{ "<F5>", function() require("dap").continue() end, desc = "Debug: Start/Continue" },
			{ "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
			{ "<F10>", function() require("dap").step_over() end, desc = "Debug: Step Over" },
			{ "<F11>", function() require("dap").step_into() end, desc = "Debug: Step Into" },
			{ "<F12>", function() require("dap").step_out() end, desc = "Debug: Step Out" },

			{ "<leader>Dc", function() require("dap").continue() end, desc = "Start/Continue" },
			{ "<leader>Db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
			{
				"<leader>DB",
				function()
					vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
						if cond and cond ~= "" then
							require("dap").set_breakpoint(cond)
						end
					end)
				end,
				desc = "Conditional Breakpoint",
			},
			{
				"<leader>Dl",
				function()
					vim.ui.input({ prompt = "Log point message: " }, function(msg)
						if msg and msg ~= "" then
							require("dap").set_breakpoint(nil, nil, msg)
						end
					end)
				end,
				desc = "Log Point",
			},
			{ "<leader>Dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
			{ "<leader>DL", function() require("dap").run_last() end, desc = "Run Last" },
			{ "<leader>Dt", function() require("dap").terminate() end, desc = "Terminate" },
			{ "<leader>Dp", function() require("dap").pause() end, desc = "Pause" },
			{ "<leader>Du", function() require("dapui").toggle() end, desc = "Toggle Debug UI" },
			{
				"<leader>De",
				function() require("dapui").eval() end,
				mode = { "n", "v" },
				desc = "Eval Expression",
			},
			{
				"<leader>DC",
				function() require("dap").clear_breakpoints() end,
				desc = "Clear All Breakpoints",
			},
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			dapui.setup({
				icons = { expanded = "\u{eab4}", collapsed = "\u{eab6}", current_frame = "\u{eab6}" },
				controls = {
					icons = {
						pause = "\u{ead1}",
						play = "\u{eb2c}",
						step_into = "\u{ead4}",
						step_over = "\u{ead6}",
						step_out = "\u{ead5}",
						step_back = "\u{eb8f}",
						run_last = "\u{ead2}",
						terminate = "\u{ead7}",
						disconnect = "\u{ead0}",
					},
				},
			})

			dap.listeners.after.event_initialized["dapui_config"] = dapui.open
			dap.listeners.before.event_terminated["dapui_config"] = dapui.close
			dap.listeners.before.event_exited["dapui_config"] = dapui.close

			vim.fn.sign_define(
				"DapBreakpoint",
				{ text = "●", texthl = "DiagnosticError", numhl = "" }
			)
			vim.fn.sign_define(
				"DapBreakpointCondition",
				{ text = "◆", texthl = "DiagnosticWarn", numhl = "" }
			)
			vim.fn.sign_define(
				"DapLogPoint",
				{ text = "◉", texthl = "DiagnosticInfo", numhl = "" }
			)
			vim.fn.sign_define(
				"DapStopped",
				{ text = "▶", texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "DiagnosticOk" }
			)

			-- Highlight the line the debugger is paused on
			local function dap_stopped_hl()
				vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
			end
			dap_stopped_hl()
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = vim.api.nvim_create_augroup("dap-stopped-hl", { clear = true }),
				callback = dap_stopped_hl,
			})

			local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"

			-- codelldb serves C, C++ and Rust.
			dap.adapters.codelldb = {
				type = "server",
				port = "${port}",
				executable = {
					command = mason_bin .. "codelldb",
					args = { "--port", "${port}" },
				},
			}

			-- js-debug-adapter serves Node and browser targets.
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = mason_bin .. "js-debug-adapter",
					args = { "${port}" },
				},
			}

			local function pick_executable()
				local default = vim.fn.getcwd() .. "/build/main"
				if not vim.uv.fs_stat(default) then
					default = vim.fn.getcwd() .. "/"
				end
				return vim.fn.input("Path to executable: ", default, "file")
			end

			local function codelldb_configurations()
				return {
					{
						name = "Launch executable",
						type = "codelldb",
						request = "launch",
						program = pick_executable,
						cwd = "${workspaceFolder}",
						stopOnEntry = false,
					},
					{
						name = "Attach to process",
						type = "codelldb",
						request = "attach",
						pid = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end

			local function node_configurations()
				return {
					{
						name = "Launch current file",
						type = "pwa-node",
						request = "launch",
						program = "${file}",
						cwd = "${workspaceFolder}",
						sourceMaps = true,
					},
					{
						name = "Attach to process",
						type = "pwa-node",
						request = "attach",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
						sourceMaps = true,
					},
				}
			end

			-- Each filetype gets its own table: adapters that append configurations
			-- would otherwise mutate a shared one and duplicate entries everywhere.
			for _, ft in ipairs({ "c", "cpp", "rust" }) do
				dap.configurations[ft] = codelldb_configurations()
			end
			for _, ft in ipairs({
				"javascript",
				"typescript",
				"javascriptreact",
				"typescriptreact",
			}) do
				dap.configurations[ft] = node_configurations()
			end
		end,
	},

	{
		"leoluz/nvim-dap-go",
		ft = "go",
		dependencies = { "mfussenegger/nvim-dap" },
		opts = {},
		keys = {
			{
				"<leader>Dg",
				function() require("dap-go").debug_test() end,
				ft = "go",
				desc = "Debug Nearest Go Test",
			},
		},
	},

	{
		"mfussenegger/nvim-dap-python",
		ft = "python",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			local venv = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
			require("dap-python").setup(vim.uv.fs_stat(venv) and venv or "python3")
		end,
	},

	-- Test running via neotest
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"nvim-neotest/neotest-python",
			"fredrikaverpil/neotest-golang",
			"marilari88/neotest-vitest",
			"nvim-neotest/neotest-jest",
		},
		keys = {
			{
				"<leader>tt",
				function() require("neotest").run.run() end,
				desc = "Run Nearest Test",
			},
			{
				"<leader>tf",
				function() require("neotest").run.run(vim.fn.expand("%")) end,
				desc = "Run File",
			},
			{
				"<leader>tA",
				function() require("neotest").run.run(vim.uv.cwd()) end,
				desc = "Run All Tests",
			},
			{
				"<leader>tl",
				function() require("neotest").run.run_last() end,
				desc = "Run Last Test",
			},
			{
				"<leader>td",
				function() require("neotest").run.run({ strategy = "dap" }) end,
				desc = "Debug Nearest Test",
			},
			{
				"<leader>ts",
				function() require("neotest").summary.toggle() end,
				desc = "Toggle Summary",
			},
			{
				"<leader>to",
				function() require("neotest").output.open({ enter = true, auto_close = true }) end,
				desc = "Show Output",
			},
			{
				"<leader>tO",
				function() require("neotest").output_panel.toggle() end,
				desc = "Toggle Output Panel",
			},
			{
				"<leader>tS",
				function() require("neotest").run.stop() end,
				desc = "Stop Test Run",
			},
			{
				"<leader>tw",
				function() require("neotest").watch.toggle(vim.fn.expand("%")) end,
				desc = "Toggle Watch File",
			},
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-python")({
						dap = { justMyCode = false },
					}),
					require("neotest-golang")({
						dap_go_enabled = true,
					}),
					require("neotest-vitest"),
					require("neotest-jest")({
						jestCommand = "npm test --",
						cwd = function()
							return vim.fn.getcwd()
						end,
					}),
				},
				status = { virtual_text = true },
				output = { open_on_run = false },
				quickfix = { enabled = false },
			})
		end,
	},
}
