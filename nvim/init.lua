-- bootstrap lazy.nvim, LazyVim and your plugins
require("trcolour").setup({})
require("config.lazy")
pcall(require, "config.render_markdown")
