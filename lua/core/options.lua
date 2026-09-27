vim.o.shell = os.getenv("SHELL")
vim.o.shellcmdflag = "-c"
vim.o.shellquote = ""
vim.o.shellxquote = ""

local options = {
  number = true,
  relativenumber = true,
  mouse = "a",
  showmode = false,
  clipboard = "",
  breakindent = true,
  undofile = true,
  ignorecase = true,
  smartcase = true,
  signcolumn = "yes",
  updatetime = 250,
  timeoutlen = 300,
  splitright = true,
  splitbelow = true,
  list = true,
  inccommand = "split",
  cursorline = true,
  scrolloff = 8,
  -- Block in normal, beam in insert, underline in replace; blink while inserting
  guicursor = "n-v-c-sm:block,i-ci-ve:ver25-blinkwait300-blinkon200-blinkoff150,r-cr-o:hor20",
  termguicolors = true,
  swapfile = false,
  winborder = "rounded",
  -- Global statusline (quieter chrome with splits)
  laststatus = 3,
  -- Never show the tab line; the review tab is reached with <leader>gd (or gt/gT)
  showtabline = 0,
  -- noice.nvim draws the cmdline as a popup, so the bottom row is free
  cmdheight = 0,
  pumheight = 12,
  pumblend = 0,
  winblend = 0,
  smoothscroll = true,
  splitkeep = "screen",
  numberwidth = 3,
  title = true,
  titlestring = "%t — nvim",
  -- Treesitter folds, all open by default; foldtext="" keeps syntax colours on folded lines
  foldmethod = "expr",
  foldexpr = "v:lua.vim.treesitter.foldexpr()",
  foldtext = "",
  foldlevel = 99,
  foldlevelstart = 99,
}

for key, value in pairs(options) do
  vim.opt[key] = value
end

vim.opt.listchars = {
  -- Tabs are shown by the indent guides instead
  tab = "  ",
  trail = "·",
  nbsp = "␣",
}

vim.opt.fillchars = {
  eob = " ",
  fold = " ",
  foldopen = "\u{f47c}",
  foldclose = "\u{f460}",
  foldsep = " ",
  diff = "\u{2571}",
}

vim.opt.shortmess:append({ I = true, c = true, W = true })
