return {
  {
    "nvim-mini/mini.surround",
    version = false,
    lazy = false,    -- load immediately so mappings are present early
    priority = 1001, -- keep early in case other plugins touch the same keys
    config = function()
      local mini_surround = require("mini.surround")
      --local prefix = "<leader>r"
      local prefix = "s"

      mini_surround.setup({
        mappings = {
          add = prefix,
          delete = prefix .. "d",
          find = prefix .. "f",
          find_left = prefix .. "F",
          highlight = prefix .. "h",
          replace = prefix .. "r",
          suffix_last = "l",
          suffix_next = "n",
        },
      })
    end,
  },
}
