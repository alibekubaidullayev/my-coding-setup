-- Start screen shown when nvim opens without a file.
local header = {
	[[                                                    ]],
	[[ ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ]],
	[[ ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ]],
	[[ ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ]],
	[[ ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ]],
	[[ ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ]],
	[[ ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ]],
	[[                                                    ]],
}

-- Lackluster: luster -> gray -> mint, one colour per header line
local gradient = { "#deeeed", "#deeeed", "#cccccc", "#aaaaaa", "#8a9a8a", "#789978", "#789978", "#555555" }

local function set_header_hl()
	for i, color in ipairs(gradient) do
		vim.api.nvim_set_hl(0, "AlphaHeader" .. i, { fg = color, bold = true })
	end
end

return {
	"goolord/alpha-nvim",
	event = "VimEnter",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local alpha = require("alpha")
		local dashboard = require("alpha.themes.dashboard")

		set_header_hl()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("alpha-header-hl", { clear = true }),
			callback = set_header_hl,
		})

		local header_lines = {}
		for i, line in ipairs(header) do
			table.insert(header_lines, {
				type = "text",
				val = line,
				opts = { hl = "AlphaHeader" .. i, position = "center" },
			})
		end

		local function button(key, icon, label, cmd)
			local b = dashboard.button(key, icon .. "  " .. label, cmd)
			b.opts.hl = "AlphaButtons"
			b.opts.hl_shortcut = "AlphaShortcut"
			b.opts.width = 44
			b.opts.cursor = 3
			return b
		end

		local buttons = {
			type = "group",
			val = {
				button("f", "\u{f002}", "Find file", "<cmd>Telescope find_files<cr>"),
				button("s", "\u{f1da}", "Restore session", "<cmd>lua require('persistence').load()<cr>"),
				button("r", "\u{f017}", "Recent files", "<cmd>Telescope oldfiles<cr>"),
				button("g", "\u{f0b0}", "Live grep", "<cmd>Telescope live_grep<cr>"),
				button("e", "\u{f07b}", "Explorer", "<cmd>lua require('oil').open_float(nil, { preview = {} })<cr>"),
				button("n", "\u{f15b}", "New file", "<cmd>enew<cr>"),
				button("c", "\u{f013}", "Config", "<cmd>lua require('telescope.builtin').find_files({ cwd = vim.fn.stdpath('config') })<cr>"),
				button("t", "\u{f1fc}", "Theme", "<cmd>lua require('core.theme').pick()<cr>"),
				button("l", "\u{f1b2}", "Lazy", "<cmd>Lazy<cr>"),
				button("m", "\u{f0ad}", "Mason", "<cmd>Mason<cr>"),
				button("q", "\u{f011}", "Quit", "<cmd>qa<cr>"),
			},
			opts = { spacing = 1 },
		}
		local footer = {
			type = "text",
			val = "",
			opts = { hl = "AlphaFooter", position = "center" },
		}

		local cwd = {
			type = "text",
			val = "\u{f07c}  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
			opts = { hl = "Comment", position = "center" },
		}

		alpha.setup({
			layout = {
				{ type = "padding", val = math.max(2, math.floor(vim.o.lines * 0.12)) },
				{ type = "group", val = header_lines },
				cwd,
				{ type = "padding", val = 2 },
				buttons,
				{ type = "padding", val = 1 },
				footer,
			},
			opts = { margin = 5 },
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "LazyVimStarted",
			once = true,
			callback = function()
				local stats = require("lazy").stats()
				local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
				footer.val = string.format("\u{f0e7} %d/%d plugins loaded in %sms", stats.loaded, stats.count, ms)
				pcall(vim.cmd.AlphaRedraw)
			end,
		})

		-- Hide chrome on the dashboard
		vim.api.nvim_create_autocmd("User", {
			pattern = "AlphaReady",
			callback = function()
				vim.opt_local.foldenable = false
				vim.b.miniindentscope_disable = true
			end,
		})
	end,
}
