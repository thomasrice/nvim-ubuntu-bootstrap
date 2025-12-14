return {
  "folke/flash.nvim",
  event = "VeryLazy",
  ---@type Flash.Config
  opts = {
    highlight = {
      -- raise the priority so our custom colors always win
      priority = 9000,
    },
    modes = {
      search = {
        enabled = true,
      },
      char = {
        jump_labels = true,
      },
    },
  },
  config = function(_, opts)
    local flash = require("flash")
    flash.setup(opts)

    local highlight_overrides = {
      FlashLabel = { fg = "#f9cbeb", bg = "#FD2675", bold = true },
      FlashMatch = { fg = "#A8DCFF", bg = "#2560A9", bold = true },
      FlashCurrent = { fg = "#F6E1FF", bg = "#966CD5", bold = true },
      FlashBackdrop = { fg = "#4b5563" },
    }

    local function apply_highlights()
      for group, spec in pairs(highlight_overrides) do
        vim.api.nvim_set_hl(0, group, spec)
      end
    end

    local augroup = vim.api.nvim_create_augroup("FlashHighlightOverrides", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = augroup,
      callback = apply_highlights,
      desc = "Re-apply vivid flash highlights after colorscheme changes",
    })

    apply_highlights()
  end,
  keys = {
    -- Disable LazyVim's default `s` mapping so mini.surround can use it
    { "s", mode = { "n", "x", "o" }, false },
    { "<Enter>", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    -- { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
    { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
    { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
