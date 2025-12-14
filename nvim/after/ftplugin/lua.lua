-- Enable the built-in Lua LSP (sumneko or lua_ls)
require("lspconfig").lua_ls.setup({
  settings = {
    Lua = {
      format = { enable = true },
    },
  },
})

-- Autoformat on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.lua",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
