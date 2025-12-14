-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.root_spec = { "cwd" } -- force LazyVim root detection to stay on the launching directory

local cargo_bin = vim.fn.expand("~/.cargo/bin")
if cargo_bin ~= "" and not vim.env.PATH:find(cargo_bin, 1, true) then
  vim.env.PATH = cargo_bin .. ":" .. vim.env.PATH
end

vim.g.autoformat = false
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = true
vim.opt.foldlevel = 99

vim.opt.fillchars = {
  eob = "-",
  fold = " ",
  foldopen = "▼",   -- when the fold is open
  foldclose = "▶",  -- when the fold is closed (your “>” replacement)
  foldsep = "│",    -- vertical separator between nested folds
}

vim.opt.viewoptions:remove("options")
vim.opt.iskeyword:append("-")
vim.opt.spelllang = { "en" }
vim.opt.spellcapcheck = "[.?!]\\_[\\])'\"\\t ]\\+"
vim.o.scrolloff = 15

vim.opt.guicursor = {
  "n-v-c-sm:block",
  "i-ci-ve:block-CursorInsert",
  "r-cr-o:hor20",
}
