-- lackluster, extended to every plugin in this config so nvim matches tmux,
-- ghostty and `ta`: near-black, grayscale, one muted mint accent.
-- Borders: #2a2a2a for panels, #444444 for inputs / single floats.
-- Selection: #191919 row, mint caret, matches in bold white.
local M = {}

local c = {
	bg = "#101010",
	bg_soft = "#141414",
	bg_line = "#191919",
	gray1 = "#1f1f1f",
	gray3 = "#2a2a2a",
	gray4 = "#444444",
	gray5 = "#555555",
	gray6 = "#7a7a7a",
	gray7 = "#aaaaaa",
	gray8 = "#cccccc",
	fg = "#deeeed",
	mint = "#789978",
	lack = "#708090",
	blue = "#7788aa",
	yellow = "#abab77",
	orange = "#ffaa88",
	red = "#d70000",
	black = "#000000",
}
M.colors = c

function M.is_active()
	return (vim.g.colors_name or ""):match("^lackluster") ~= nil
end

-- Pill-style lualine theme: mode badge carries the (muted) mode colour,
-- everything else sits flush on the editor background like the tmux bar.
function M.lualine()
	local function mode(bg)
		return {
			a = { bg = bg, fg = c.bg, gui = "bold" },
			b = { bg = c.bg_line, fg = c.gray7 },
			c = { bg = c.bg, fg = c.gray6 },
			x = { bg = c.bg, fg = c.gray5 },
			y = { bg = c.bg_line, fg = c.gray7 },
			z = { bg = bg, fg = c.bg, gui = "bold" },
		}
	end
	return {
		normal = mode(c.gray8),
		insert = mode(c.mint),
		visual = mode(c.lack),
		replace = mode(c.orange),
		command = mode(c.fg),
		terminal = mode(c.blue),
		inactive = {
			a = { bg = c.bg, fg = c.gray4 },
			b = { bg = c.bg, fg = c.gray4 },
			c = { bg = c.bg, fg = c.gray4 },
		},
	}
end

-- modes.nvim line tints
M.modes = {
	bg = c.bg,
	copy = c.yellow,
	delete = c.red,
	change = c.orange,
	format = c.blue,
	insert = c.mint,
	replace = c.orange,
	select = c.lack,
	visual = c.lack,
}

local function groups()
	local panel = { fg = c.gray3, bg = c.bg }
	local input = { fg = c.gray4, bg = c.bg }
	local title = { fg = c.gray8, bold = true }
	local sel = { fg = c.fg, bg = c.bg_line, bold = true }
	local match = { fg = c.fg, bold = true, underline = true }

	return {
		-- editor chrome
		WinSeparator = { fg = c.gray3 },
		CursorLineNr = { fg = c.gray8, bold = true },
		Folded = { fg = c.gray6, bg = c.bg_soft },
		LspInlayHint = { fg = c.gray5, bg = c.bg_soft, italic = true },
		TreesitterContext = { bg = c.bg_soft },
		TreesitterContextLineNumber = { fg = c.gray4, bg = c.bg_soft },
		TreesitterContextBottom = { sp = c.gray3, underline = true },
		IlluminatedWordText = { bg = c.gray1 },
		IlluminatedWordRead = { bg = c.gray1 },
		IlluminatedWordWrite = { bg = c.gray1, underline = true },
		IblIndent = { fg = c.gray1 },
		IblWhitespace = { fg = c.gray1 },
		SatelliteBar = { bg = c.gray3 },

		-- floats
		NormalFloat = { fg = c.gray8, bg = c.bg },
		FloatBorder = input,
		FloatTitle = title,
		FloatFooter = { fg = c.gray5 },

		-- completion (nvim-cmp maps Normal->Pmenu inside its bordered window)
		Pmenu = { fg = c.gray7, bg = c.bg },
		PmenuSel = sel,
		PmenuSbar = { bg = c.bg_line },
		PmenuThumb = { bg = c.gray4 },
		CmpGhostText = { fg = c.gray4, italic = true },
		CmpItemAbbr = { fg = c.gray7 },
		CmpItemAbbrMatch = { fg = c.fg, bold = true },
		CmpItemAbbrMatchFuzzy = { fg = c.fg, bold = true },
		CmpItemAbbrDeprecated = { fg = c.gray5, strikethrough = true },
		CmpItemMenu = { fg = c.gray5, italic = true },
		CmpItemKind = { fg = c.gray6 },
		CmpItemKindFunction = { fg = c.mint },
		CmpItemKindMethod = { fg = c.mint },
		CmpItemKindConstructor = { fg = c.mint },
		CmpItemKindClass = { fg = c.lack },
		CmpItemKindStruct = { fg = c.lack },
		CmpItemKindInterface = { fg = c.lack },
		CmpItemKindModule = { fg = c.blue },
		CmpItemKindVariable = { fg = c.gray8 },
		CmpItemKindField = { fg = c.gray8 },
		CmpItemKindProperty = { fg = c.gray8 },
		CmpItemKindSnippet = { fg = c.yellow },
		CmpItemKindKeyword = { fg = c.gray6 },
		CmpItemKindText = { fg = c.gray5 },

		-- telescope: same layout language as `ta`
		TelescopeNormal = { fg = c.gray7, bg = c.bg },
		TelescopeBorder = panel,
		TelescopeResultsBorder = panel,
		TelescopePreviewBorder = panel,
		TelescopePromptBorder = input,
		TelescopePromptNormal = { fg = c.fg, bg = c.bg },
		TelescopePromptPrefix = { fg = c.mint },
		TelescopePromptCounter = { fg = c.gray5 },
		TelescopeTitle = { fg = c.gray6 },
		TelescopeResultsTitle = { fg = c.gray6 },
		TelescopePreviewTitle = { fg = c.gray6 },
		TelescopePromptTitle = title,
		TelescopeSelection = sel,
		TelescopeSelectionCaret = { fg = c.mint, bg = c.bg_line },
		TelescopeMultiSelection = { fg = c.mint },
		TelescopeMatching = match,

		-- noice cmdline popup
		NoiceCmdlinePopup = { fg = c.fg, bg = c.bg },
		NoiceCmdlinePopupBorder = input,
		NoiceCmdlinePopupTitle = title,
		NoiceCmdlineIcon = { fg = c.mint },
		NoiceCmdlinePopupBorderSearch = input,
		NoiceCmdlineIconSearch = { fg = c.yellow },
		NoiceConfirmBorder = input,
		NoicePopupBorder = input,
		NoicePopupmenuBorder = input,

		-- which-key
		WhichKeyNormal = { bg = c.bg },
		WhichKeyBorder = input,
		WhichKeyTitle = title,
		WhichKey = { fg = c.fg, bold = true },
		WhichKeyGroup = { fg = c.mint },
		WhichKeyDesc = { fg = c.gray7 },
		WhichKeySeparator = { fg = c.gray4 },
		WhichKeyValue = { fg = c.gray5 },
		WhichKeyIconAzure = { fg = c.lack },
		WhichKeyIconBlue = { fg = c.blue },
		WhichKeyIconCyan = { fg = c.lack },
		WhichKeyIconGreen = { fg = c.mint },
		WhichKeyIconGrey = { fg = c.gray6 },
		WhichKeyIconOrange = { fg = c.orange },
		WhichKeyIconPurple = { fg = c.lack },
		WhichKeyIconRed = { fg = c.orange },
		WhichKeyIconYellow = { fg = c.yellow },

		-- dashboard
		AlphaButtons = { fg = c.gray7 },
		AlphaShortcut = { fg = c.mint, bold = true },
		AlphaFooter = { fg = c.gray5, italic = true },

		-- notifications
		NotifyBackground = { bg = c.bg },
		NotifyERRORBorder = panel,
		NotifyWARNBorder = panel,
		NotifyINFOBorder = panel,
		NotifyDEBUGBorder = panel,
		NotifyTRACEBorder = panel,
		NotifyERRORIcon = { fg = c.red },
		NotifyERRORTitle = { fg = c.red, bold = true },
		NotifyWARNIcon = { fg = c.orange },
		NotifyWARNTitle = { fg = c.orange, bold = true },
		NotifyINFOIcon = { fg = c.mint },
		NotifyINFOTitle = { fg = c.mint, bold = true },
		NotifyDEBUGIcon = { fg = c.gray6 },
		NotifyDEBUGTitle = { fg = c.gray6, bold = true },
		NotifyTRACEIcon = { fg = c.lack },
		NotifyTRACETitle = { fg = c.lack, bold = true },
		NotifyERRORBody = { fg = c.gray8, bg = c.bg },
		NotifyWARNBody = { fg = c.gray8, bg = c.bg },
		NotifyINFOBody = { fg = c.gray8, bg = c.bg },
		NotifyDEBUGBody = { fg = c.gray8, bg = c.bg },
		NotifyTRACEBody = { fg = c.gray8, bg = c.bg },

		-- LSP progress
		FidgetTitle = { fg = c.gray8, bold = true },
		FidgetTask = { fg = c.gray5 },

		-- flash jump labels: monochrome, like a selection
		FlashBackdrop = { fg = c.gray4 },
		FlashMatch = { fg = c.gray7 },
		FlashCurrent = { fg = c.fg, underline = true },
		FlashLabel = { fg = c.black, bg = c.fg, bold = true },

		-- dropbar menus
		DropBarMenuHoverEntry = { bg = c.bg_line },
		DropBarMenuCurrentContext = { bg = c.bg_line },
		DropBarIconUISeparator = { fg = c.gray4 },

		-- brackets by depth: grays interleaved with the muted accents
		RainbowDelimiterRed = { fg = c.gray7 },
		RainbowDelimiterYellow = { fg = c.mint },
		RainbowDelimiterBlue = { fg = c.blue },
		RainbowDelimiterOrange = { fg = c.gray6 },
		RainbowDelimiterGreen = { fg = c.lack },
		RainbowDelimiterViolet = { fg = c.yellow },
		RainbowDelimiterCyan = { fg = c.gray8 },

		-- markdown
		RenderMarkdownH1 = { fg = c.mint, bold = true },
		RenderMarkdownH2 = { fg = c.blue, bold = true },
		RenderMarkdownH3 = { fg = c.yellow, bold = true },
		RenderMarkdownH4 = { fg = c.gray8, bold = true },
		RenderMarkdownH5 = { fg = c.gray7, bold = true },
		RenderMarkdownH6 = { fg = c.gray6, bold = true },
		RenderMarkdownH1Bg = { bg = "#171d17" },
		RenderMarkdownH2Bg = { bg = "#17191f" },
		RenderMarkdownH3Bg = { bg = "#1c1c16" },
		RenderMarkdownH4Bg = { bg = c.bg_line },
		RenderMarkdownH5Bg = { bg = c.bg_line },
		RenderMarkdownH6Bg = { bg = c.bg_line },
		RenderMarkdownCode = { bg = c.bg_soft },
		RenderMarkdownCodeInline = { fg = c.gray8, bg = c.bg_line },
	}
end

function M.apply()
	for name, spec in pairs(groups()) do
		vim.api.nvim_set_hl(0, name, spec)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("lackluster-extend", { clear = true }),
		pattern = "lackluster*",
		callback = M.apply,
	})
end

return M
