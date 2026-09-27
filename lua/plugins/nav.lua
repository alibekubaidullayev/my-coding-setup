-- Navigation without snacks: Telescope pickers + oil/harpoon/flash.
local function telescope(builtin, opts)
	return function()
		require("telescope.builtin")[builtin](opts)
	end
end

local function scratch_toggle()
	local name = "scratch://" .. (vim.bo.filetype ~= "" and vim.bo.filetype or "txt")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):find("^scratch://", 1) then
			local wins = vim.fn.win_findbuf(buf)
			if #wins > 0 then
				vim.api.nvim_win_close(wins[1], true)
			else
				vim.api.nvim_set_current_buf(buf)
			end
			return
		end
	end
	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.api.nvim_set_current_buf(buf)
end

local function git_browse()
	local file = vim.fn.expand("%")
	local line = vim.fn.line(".")
	-- Prefer gh; fall back to opening the remote URL in the browser
	if vim.fn.executable("gh") == 1 then
		vim.fn.jobstart({ "gh", "browse", file .. ":" .. line }, { detach = true })
		return
	end
	local remote = vim.fn.systemlist("git remote get-url origin")[1]
	if not remote or remote == "" then
		vim.notify("No git remote", vim.log.levels.WARN)
		return
	end
	remote = remote:gsub("git@([^:]+):", "https://%1/"):gsub("%.git$", "")
	local rev = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1] or "main"
	vim.ui.open(string.format("%s/blob/%s/%s#L%d", remote, rev, file, line))
end

-- Live grep limited to files with uncommitted changes (tracked + untracked)
local function grep_changed()
	local files = vim.fn.systemlist("git diff --name-only --diff-filter=d HEAD --relative; git ls-files --others --exclude-standard")
	if vim.v.shell_error ~= 0 or #files == 0 then
		vim.notify("No changed files", vim.log.levels.WARN)
		return
	end
	require("telescope.builtin").live_grep({ search_dirs = files, prompt_title = "Grep Changed Files" })
end

local function lazygit()
	if vim.fn.executable("lazygit") == 0 then
		vim.notify("lazygit not found in PATH", vim.log.levels.ERROR)
		return
	end
	vim.cmd("tabnew | terminal lazygit")
	vim.cmd("startinsert")
end

return {
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		-- 0.1.x lacks position_encoding for nvim 0.11+ LSP (yellow warn on gr/gd/…)
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
			"nvim-telescope/telescope-ui-select.nvim",
			"debugloop/telescope-undo.nvim",
		},
		config = function()
			local telescope = require("telescope")
			local actions = require("telescope.actions")

			-- Fit cursor-menu height to result count (drops empty rows under the list).
			-- Cursor layout: total = results + prompt(1) + border spacing(~3).
			local function lsp_menu_height(self, _, max_lines)
				local n = 1
				if self.finder and self.finder.results then
					n = math.max(#self.finder.results, 1)
				end
				return math.min(n + 4, 16, max_lines)
			end

			local lsp_cursor = {
				theme = "cursor",
				previewer = false,
				initial_mode = "normal",
				layout_config = { width = 70, height = lsp_menu_height },
			}

			telescope.setup({
				defaults = {
					borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
					prompt_prefix = " \u{f002}  ",
					selection_caret = " \u{f054} ",
					entry_prefix = "   ",
					multi_icon = " \u{f00c} ",
					sorting_strategy = "ascending",
					layout_strategy = "horizontal",
					layout_config = {
						horizontal = {
							prompt_position = "top",
							preview_width = 0.55,
						},
						width = 0.87,
						height = 0.80,
					},
					results_title = false,
					dynamic_preview_title = true,
					path_display = { "filename_first" },
					mappings = {
						i = {
							["<C-u>"] = false,
							["<C-d>"] = false,
							["<esc>"] = actions.close,
						},
						n = {
							["q"] = actions.close,
						},
					},
				},
				-- Built-in cursor theme = Telescope's context-menu style for LSP jumps
				pickers = {
					lsp_references = lsp_cursor,
					lsp_definitions = lsp_cursor,
					lsp_implementations = lsp_cursor,
					lsp_type_definitions = lsp_cursor,
					lsp_incoming_calls = lsp_cursor,
					lsp_outgoing_calls = lsp_cursor,
				},
				extensions = {
					["ui-select"] = require("telescope.themes").get_dropdown(),
					undo = {},
				},
			})
			pcall(telescope.load_extension, "fzf")
			pcall(telescope.load_extension, "ui-select")
			pcall(telescope.load_extension, "undo")
		end,
		keys = {
			{ "<leader><leader>", telescope("buffers"), desc = "Buffers" },
			{ "<leader>/", telescope("live_grep"), desc = "Grep" },
			{ "<leader>:", telescope("command_history"), desc = "Command History" },
			{ "<leader>n", "<cmd>Notifications<cr>", desc = "Notification History" },

			{ "<leader>sf", telescope("find_files"), desc = "[S]earch [F]iles" },
			{ "<leader>s.", telescope("oldfiles"), desc = "[S]earch Recent Files" },
			{
				"<leader>sn",
				function()
					require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
				end,
				desc = "[S]earch [N]eovim files",
			},
			{ "<leader>ss", telescope("builtin"), desc = "[S]earch [S]elect Picker" },

			{ "<leader>gb", telescope("git_branches"), desc = "Git Branches" },
			{ "<leader>gl", telescope("git_commits"), desc = "Git Log" },
			{ "<leader>gL", telescope("git_bcommits"), desc = "Git Log Line" },
			{ "<leader>gs", telescope("git_status"), desc = "Git Status" },
			{ "<leader>gS", telescope("git_stash"), desc = "Git Stash" },
			{ "<leader>gf", telescope("git_bcommits"), desc = "Git Log File" },

			-- GitHub via gh CLI (select UI)
			{
				"<leader>gi",
				function()
					local issues = vim.fn.systemlist("gh issue list --limit 30 --json number,title --jq '.[] | \"#\\(.number) \\(.title)\"'")
					if vim.v.shell_error ~= 0 or #issues == 0 then
						vim.notify("No open issues (or gh failed)", vim.log.levels.WARN)
						return
					end
					vim.ui.select(issues, { prompt = "GitHub Issues" }, function(choice)
						if not choice then
							return
						end
						local num = choice:match("#(%d+)")
						if num then
							vim.fn.jobstart({ "gh", "issue", "view", num, "--web" }, { detach = true })
						end
					end)
				end,
				desc = "GitHub Issues (open)",
			},
			{
				"<leader>gp",
				function()
					local prs = vim.fn.systemlist("gh pr list --limit 30 --json number,title --jq '.[] | \"#\\(.number) \\(.title)\"'")
					if vim.v.shell_error ~= 0 or #prs == 0 then
						vim.notify("No open PRs (or gh failed)", vim.log.levels.WARN)
						return
					end
					vim.ui.select(prs, { prompt = "GitHub PRs" }, function(choice)
						if not choice then
							return
						end
						local num = choice:match("#(%d+)")
						if num then
							vim.fn.jobstart({ "gh", "pr", "view", num, "--web" }, { detach = true })
						end
					end)
				end,
				desc = "GitHub Pull Requests (open)",
			},
			{ "<leader>gI", "<leader>gi", desc = "GitHub Issues", remap = true },
			{ "<leader>gP", "<leader>gp", desc = "GitHub PRs", remap = true },

			{ "<leader>sb", telescope("current_buffer_fuzzy_find"), desc = "Buffer Lines" },
			{ "<leader>sB", telescope("live_grep", { grep_open_files = true }), desc = "Grep Open Buffers" },
			{ "<leader>sg", telescope("live_grep"), desc = "Grep" },
			{ "<leader>sG", grep_changed, desc = "Grep changed files" },
			{
				"<leader>sw",
				function()
					require("telescope.builtin").grep_string()
				end,
				desc = "Visual selection or word",
				mode = { "n", "x" },
			},

			{ '<leader>s"', telescope("registers"), desc = "Registers" },
			{ "<leader>s/", telescope("search_history"), desc = "Search History" },
			{ "<leader>sa", telescope("autocommands"), desc = "Autocmds" },
			{ "<leader>sc", telescope("command_history"), desc = "Command History" },
			{ "<leader>sC", telescope("commands"), desc = "Commands" },
			{ "<leader>sd", telescope("diagnostics"), desc = "Diagnostics" },
			{
				"<leader>sD",
				function()
					require("telescope.builtin").diagnostics({ bufnr = 0 })
				end,
				desc = "Buffer Diagnostics",
			},
			{ "<leader>sh", telescope("help_tags"), desc = "Help Pages" },
			{ "<leader>sH", telescope("highlights"), desc = "Highlights" },
			{ "<leader>sj", telescope("jumplist"), desc = "Jumps" },
			{ "<leader>sk", telescope("keymaps"), desc = "Keymaps" },
			{ "<leader>sl", telescope("loclist"), desc = "Location List" },
			{ "<leader>sm", telescope("marks"), desc = "Marks" },
			{ "<leader>sM", telescope("man_pages"), desc = "Man Pages" },
			{ "<leader>sq", telescope("quickfix"), desc = "Quickfix List" },
			{ "<leader>sr", telescope("resume"), desc = "[S]earch [R]esume" },
			{
				"<leader>su",
				function()
					require("telescope").extensions.undo.undo()
				end,
				desc = "Undo History",
			},
			-- plugin-spec search: approximate with files in config
			{
				"<leader>sp",
				function()
					require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") .. "/lua/plugins" })
				end,
				desc = "Search Plugin Specs",
			},

			{ "gd", telescope("lsp_definitions"), desc = "Goto Definition" },
			{ "gr", telescope("lsp_references"), nowait = true, desc = "References" },
			{ "gI", telescope("lsp_implementations"), desc = "Goto Implementation" },
			{ "gy", telescope("lsp_type_definitions"), desc = "Goto T[y]pe Definition" },
			{ "gai", telescope("lsp_incoming_calls"), desc = "C[a]lls Incoming" },
			{ "gao", telescope("lsp_outgoing_calls"), desc = "C[a]lls Outgoing" },
			{ "<leader>o", telescope("lsp_document_symbols"), desc = "Document Symbols" },
			{ "<leader>so", telescope("lsp_document_symbols"), desc = "Document Symbols" },
			{ "<leader>sS", telescope("lsp_dynamic_workspace_symbols"), desc = "Workspace Symbols" },
			{ "<leader>rn", vim.lsp.buf.rename, desc = "Rename" },
			{ "<leader>ca", vim.lsp.buf.code_action, mode = { "n", "x" }, desc = "Code Action" },

			{ "<leader>.", scratch_toggle, desc = "Toggle Scratch Buffer" },
			{
				"<leader>bd",
				function()
					require("mini.bufremove").delete(0, false)
				end,
				desc = "Delete Buffer",
			},
			{ "<leader>gB", git_browse, desc = "Git Browse", mode = { "n", "v" } },
			{ "<leader>gg", lazygit, desc = "Lazygit" },
			{
				"<leader>un",
				function()
					require("notify").dismiss({ silent = true, pending = true })
				end,
				desc = "Dismiss All Notifications",
			},
			{
				"<leader>N",
				function()
					vim.cmd("help news")
				end,
				desc = "Neovim News",
			},
		},
	},
	{
		"stevearc/oil.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		lazy = false,
		opts = {
			default_file_explorer = true,
			delete_to_trash = true,
			skip_confirm_for_simple_edits = true,
			view_options = {
				show_hidden = true,
			},
			-- Match Telescope: quiet list pane, cursorline as selection
			win_options = {
				wrap = false,
				signcolumn = "no",
				cursorcolumn = false,
				foldcolumn = "0",
				spell = false,
				list = false,
				conceallevel = 3,
				concealcursor = "nvic",
				number = false,
				relativenumber = false,
				cursorline = true,
				-- Same bg/border as Telescope (Normal), not NormalFloat popup tint
				winhighlight = table.concat({
					"Normal:TelescopeNormal",
					"NormalFloat:TelescopeNormal",
					"FloatBorder:TelescopeBorder",
					"FloatTitle:TelescopeTitle",
					"CursorLine:TelescopeSelection",
				}, ","),
			},
			float = {
				padding = 2,
				max_width = 0.9,
				max_height = 0.85,
				border = "rounded",
				preview_split = "right",
				win_options = {
					winblend = 0,
				},
			},
			preview_win = {
				update_on_cursor_moved = true,
				preview_method = "fast_scratch",
				win_options = {
					number = false,
					relativenumber = false,
					signcolumn = "no",
					wrap = false,
					winblend = 0,
					winhighlight = table.concat({
						"Normal:TelescopeNormal",
						"NormalFloat:TelescopeNormal",
						"FloatBorder:TelescopeBorder",
						"FloatTitle:TelescopeTitle",
					}, ","),
				},
			},
			keymaps = {
				["q"] = "actions.close",
				["<C-c>"] = "actions.close",
				["<C-p>"] = "actions.preview",
			},
		},
		config = function(_, opts)
			require("oil").setup(opts)

			-- Drop lackluster's special OilFile tint; use editor Normal like Telescope results
			local function sync_oil_hl()
				vim.api.nvim_set_hl(0, "OilFile", { link = "Normal" })
				vim.api.nvim_set_hl(0, "OilFileHidden", { link = "Comment" })
				vim.api.nvim_set_hl(0, "OilDir", { link = "Directory" })
				vim.api.nvim_set_hl(0, "OilDirHidden", { link = "Comment" })
				vim.api.nvim_set_hl(0, "OilDirIcon", { link = "Directory" })
			end
			sync_oil_hl()
			vim.api.nvim_create_autocmd("ColorScheme", {
				group = vim.api.nvim_create_augroup("oil-telescope-hl", { clear = true }),
				callback = sync_oil_hl,
			})
		end,
		keys = {
			{
				"<leader>e",
				function()
					-- Float + right preview (Results | Preview), like Telescope
					require("oil").toggle_float(nil, { preview = {} })
				end,
				desc = "File Explorer (oil)",
			},
		},
	},
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")
			harpoon:setup()

			vim.keymap.set("n", "<leader>m", function()
				harpoon:list():add()
			end, { desc = "Harpoon add file" })
			vim.keymap.set("n", "<C-e>", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, { desc = "Harpoon menu" })

			vim.keymap.set("n", "<C-x>", function()
				harpoon:list():select(1)
			end, { desc = "Harpoon file 1" })
			vim.keymap.set("n", "<C-c>", function()
				harpoon:list():select(2)
			end, { desc = "Harpoon file 2" })
			vim.keymap.set("n", "<C-n>", function()
				harpoon:list():select(3)
			end, { desc = "Harpoon file 3" })
			vim.keymap.set("n", "<C-b>", function()
				harpoon:list():select(4)
			end, { desc = "Harpoon file 4" })

			vim.keymap.set("n", "<C-S-H>", function()
				harpoon:list():prev()
			end, { desc = "Harpoon prev" })
			vim.keymap.set("n", "<C-S-L>", function()
				harpoon:list():next()
			end, { desc = "Harpoon next" })
		end,
	},
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		keys = {
			{
				"s",
				mode = { "n", "x", "o" },
				function()
					require("flash").jump()
				end,
				desc = "Flash",
			},
			{
				"S",
				mode = { "n", "x", "o" },
				function()
					require("flash").treesitter()
				end,
				desc = "Flash Treesitter",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
			{
				"R",
				mode = { "o", "x" },
				function()
					require("flash").treesitter_search()
				end,
				desc = "Treesitter Search",
			},
			{
				"<c-s>",
				mode = { "c" },
				function()
					require("flash").toggle()
				end,
				desc = "Toggle Flash Search",
			},
		},
		opts = {
			labels = "asdfghjklqwertyuiopzxcvbnm",
			search = { mode = "fuzzy" },
			jump = { autojump = true },
			label = { rainbow = { enabled = true } },
			modes = { char = { jump_labels = true } },
		},
	},
	{
		"RRethy/vim-illuminate",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			delay = 200,
			large_file_cutoff = 2000,
			large_file_overrides = { providers = { "lsp" } },
		},
		config = function(_, opts)
			require("illuminate").configure(opts)
			vim.keymap.set("n", "]]", function()
				require("illuminate").goto_next_reference(false)
			end, { desc = "Next Reference" })
			vim.keymap.set("n", "[[", function()
				require("illuminate").goto_prev_reference(false)
			end, { desc = "Prev Reference" })
		end,
	},
	-- Peek LSP locations in an editable float without leaving the diff you're reading.
	-- Capital = peek, lowercase (gd/gr/gy/gI) = jump.
	{
		"DNLHC/glance.nvim",
		cmd = "Glance",
		keys = {
			{ "gD", "<cmd>Glance definitions<cr>", desc = "Peek Definition" },
			{ "gR", "<cmd>Glance references<cr>", desc = "Peek References" },
			{ "gY", "<cmd>Glance type_definitions<cr>", desc = "Peek Type Definition" },
			{ "gM", "<cmd>Glance implementations<cr>", desc = "Peek Implementations" },
		},
		opts = {
			border = { enable = true },
			use_trouble_qf = true,
		},
	},
}
