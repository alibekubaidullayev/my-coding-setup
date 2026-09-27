vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", {
	desc = "Clear search highlight",
})
-- Buffer diagnostics live at <leader>xX (see plugins/diag.lua)

-- `gr` is mapped to LSP references with nowait (plugins/nav.lua), which makes
-- Nvim's default gr* maps unreachable. They're all covered elsewhere: gra/grn ->
-- <leader>ca/<leader>rn, grr/gri/grt -> gr/gI/gy.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt" }) do
	pcall(vim.keymap.del, { "n", "x" }, lhs)
end

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", {
	desc = "Exit terminal mode",
})
-- Move between splits
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })
vim.keymap.set("n", "<leader>y", '"+y', {
	desc = "Yank to system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("v", "<leader>y", '"+y', {
	desc = "Yank selection to system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("n", "<leader>Y", '"+Y', {
	desc = "Yank line to system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("n", "<leader>p", '"+p', {
	desc = "Paste from system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("n", "<leader>P", '"+P', {
	desc = "Paste before cursor from system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("n", "<leader>d", '"+d', {
	desc = "Delete to system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("v", "<leader>d", '"+d', {
	desc = "Delete selection to system clipboard",
	noremap = true,
	silent = true,
})
vim.keymap.set("i", "jk", "<Esc>", {
	desc = "Exit insert mode",
})
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", {
	desc = "Move selected lines down",
})
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", {
	desc = "Move selected lines up",
})
vim.keymap.set("n", "J", "mzJ`z", {
	desc = "Join lines and maintain cursor position",
})
vim.keymap.set("n", "<C-d>", "<C-d>zz", {
	desc = "Scroll down and center",
})
vim.keymap.set("n", "<C-u>", "<C-u>zz", {
	desc = "Scroll up and center",
})
vim.keymap.set("n", "n", "nzzzv", {
	desc = "Search forward and center",
})
vim.keymap.set("n", "N", "Nzzzv", {
	desc = "Search backward and center",
})
vim.keymap.set("n", "<C-s>", ":w<CR>", {
	desc = "Save file",
})
vim.keymap.set("n", "<C-a>", "ggVG", {
	desc = "Select all text in the file",
})

local function rebase_dir()
	local current_path = vim.fn.expand("%:p:h")
	vim.cmd.cd(current_path)
	vim.notify("Rebased to " .. current_path)
end

vim.keymap.set("n", "<leader>rb", rebase_dir, { noremap = true, silent = true, desc = "[R]e[b]ase cwd to file's dir" })

-- Quick save and quit
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit all" })

-- CMake keymaps
vim.keymap.set("n", "<leader>cp", "<cmd>!cmake -S . -B build<CR>", { desc = "[C]make Configure" })
vim.keymap.set("n", "<leader>cc", "<cmd>!cmake --build build<CR>", { desc = "[C]make Build" })
vim.keymap.set("n", "<leader>cj", "<cmd>!./build/main<CR>", { desc = "[C]make Run" })

-- Cargo (Rust) keymaps
vim.keymap.set("n", "<leader>cr", "<cmd>!cargo run<CR>", { desc = "[C]argo [R]un" })
vim.keymap.set("n", "<leader>cb", "<cmd>!cargo build<CR>", { desc = "[C]argo [B]uild" })
vim.keymap.set("n", "<leader>ct", "<cmd>!cargo test<CR>", { desc = "[C]argo [T]est" })

-- UI toggles (formerly Snacks.toggle)
vim.keymap.set("n", "<leader>us", function()
	vim.o.spell = not vim.o.spell
end, { desc = "Toggle Spelling" })
vim.keymap.set("n", "<leader>uw", function()
	vim.o.wrap = not vim.o.wrap
end, { desc = "Toggle Wrap" })
vim.keymap.set("n", "<leader>uL", function()
	vim.o.relativenumber = not vim.o.relativenumber
end, { desc = "Toggle Relative Number" })
vim.keymap.set("n", "<leader>ul", function()
	vim.o.number = not vim.o.number
end, { desc = "Toggle Line Number" })
vim.keymap.set("n", "<leader>ud", function()
	vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end, { desc = "Toggle Diagnostics" })
vim.keymap.set("n", "<leader>uc", function()
	vim.o.conceallevel = vim.o.conceallevel > 0 and 0 or 2
end, { desc = "Toggle Conceal" })
vim.keymap.set("n", "<leader>ub", function()
	vim.o.background = vim.o.background == "dark" and "light" or "dark"
end, { desc = "Toggle Background" })
vim.keymap.set("n", "<leader>uh", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
end, { desc = "Toggle Inlay Hints" })
vim.keymap.set("n", "<leader>ug", "<cmd>IBLToggle<cr>", { desc = "Toggle Indent Guides" })
vim.keymap.set("n", "<leader>uT", function()
	vim.treesitter.stop()
	vim.notify("Treesitter stopped for buffer (reopen to restart)")
end, { desc = "Stop Treesitter (buffer)" })
