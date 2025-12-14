local M = {}

M.setup = function(opts)
  local colors = opts.colors or {
    --            bg = "#282A36",
    fg = "#F8F8F2",
    selection = "#44475A",
    comment = "#6272A4",
    red = "#FF5555",
    orange = "#FFB86C",
    yellow = "#F1FA8C",
    green = "#50fa7b",
    purple = "#BD93F9",
    cyan = "#8BE9FD",
    pink = "#FF79C6",
    bright_red = "#FF6E6E",
    bright_green = "#69FF94",
    bright_yellow = "#FFFFA5",
    bright_blue = "#D6ACFF",
    bright_magenta = "#FF92DF",
    bright_cyan = "#A4FFFF",
    bright_white = "#FFFFFF",
    menu = "#21222C",
    visual = "#3E4452",
    gutter_fg = "#4B5263",
    nontext = "#3B4048",
    white = "#ABB2BF",
    black = "#191A21",
  }

  -- Set Neovim's background option
  --vim.o.background = "dark" -- or "light"

  -- Clear existing highlights (optional, but good practice)
  --vim.cmd("highlight clear")
  vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })

  -- Apply highlight groups
  vim.api.nvim_set_hl(0, "Normal", { fg = colors.fg, bg = colors.bg })
  vim.api.nvim_set_hl(0, "Comment", { fg = colors.comment, italic = true })
  vim.api.nvim_set_hl(0, "Keyword", { fg = colors.keyword })
  vim.api.nvim_set_hl(0, "SpellBad", { undercurl = true, sp = "#ff4d4d" })
  vim.api.nvim_set_hl(0, "SpellCap", { undercurl = true, sp = "#ffaf00" })
  vim.api.nvim_set_hl(0, "SpellRare", { undercurl = true, sp = "#b16286" })
  vim.api.nvim_set_hl(0, "SpellLocal", { undercurl = true, sp = "#5fd7ff" })

  -- Define more highlight groups (e.g., String, Function, LineNr, CursorLine)
  -- You can find a list of highlight groups using :help highlight-groups
end

return M
