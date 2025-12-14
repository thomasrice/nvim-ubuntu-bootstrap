return {
  {
    "L3MON4D3/LuaSnip",
    version = "*",
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = function()
      local ok_ls, ls = pcall(require, "luasnip")
      if not ok_ls then
        return
      end

      -- Load user snippets from lua/snippets (Lua format)
      local ok_lua_loader, lua_loader = pcall(require, "luasnip.loaders.from_lua")
      if ok_lua_loader and lua_loader and lua_loader.lazy_load then
        lua_loader.lazy_load({
          paths = vim.fn.stdpath("config") .. "/lua/snippets",
        })
      end

      -- Load community snippets (VSCode format)
      local ok_vscode_loader, vscode_loader = pcall(require, "luasnip.loaders.from_vscode")
      if ok_vscode_loader and vscode_loader and vscode_loader.lazy_load then
        vscode_loader.lazy_load()
      end

      ls.config.set_config({
        history = true,
        updateevents = "TextChanged,TextChangedI",
        enable_autosnippets = true,
      })
    end,
  },
}
