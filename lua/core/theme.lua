-- Colorscheme persistence + curated picker. The chosen scheme is saved on every
-- :colorscheme and restored on startup (see plugins/theme.lua).
local M = {}

M.default = "lackluster-mint"

M.curated = {
	"lackluster-mint",
	"lackluster-hack",
	"catppuccin-mocha",
	"catppuccin-macchiato",
	"catppuccin-frappe",
	"catppuccin-latte",
	"tokyonight-night",
	"tokyonight-moon",
	"tokyonight-storm",
	"kanagawa-wave",
	"kanagawa-dragon",
	"rose-pine-main",
	"rose-pine-moon",
}

local state_file = vim.fn.stdpath("state") .. "/colorscheme"

local function read_saved()
	local f = io.open(state_file, "r")
	if not f then
		return nil
	end
	local name = f:read("*l")
	f:close()
	return name ~= "" and name or nil
end

function M.apply_saved()
	local name = read_saved() or M.default
	if not pcall(vim.cmd.colorscheme, name) then
		vim.cmd.colorscheme(M.default)
	end

	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("persist-colorscheme", { clear = true }),
		callback = function(ev)
			local f = io.open(state_file, "w")
			if f then
				f:write(ev.match)
				f:close()
			end
		end,
	})
end

function M.pick()
	require("telescope.builtin").colorscheme({
		colors = M.curated,
		enable_preview = true,
		ignore_builtins = true,
	})
end

return M
