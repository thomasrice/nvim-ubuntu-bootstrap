-- Created by AI / Thomas Rice on 05/11/25

local M = {}

-- Configure a word highlighter with syntax match + mode-aware relinking
-- Usage:
--   require('util.word_highlight').setup({
--     filetypes = { 'markdown', 'markdown.mdx', 'markdown.pandoc' },
--     items = {
--       {
--         word = 'WAITING',
--         bg = { bg = '#7a3e00', fg = '#fff7ed', bold = true },
--         fg = { fg = '#f59e0b', bold = true },
--       },
--     },
--   })

local function create_groups(item)
  local base = item.word:gsub("%W", "_")
  local group_match = "WordHLMatch_" .. base
  local group_bg = "WordHLBg_" .. base
  local group_fg = "WordHLFg_" .. base

  vim.api.nvim_set_hl(0, group_bg, item.bg or { bg = '#444444', fg = '#eeeeee', bold = true })
  vim.api.nvim_set_hl(0, group_fg, item.fg or { fg = '#ff8800', bold = true })

  return group_match, group_bg, group_fg
end

local function ensure_syntax(word, match_group)
  local pat = [[\<]] .. word .. [[\>]]
  local cmd = string.format([[syntax match %s /%s/ containedin=ALL keepend]], match_group, pat)
  -- pcall to avoid duplicate definition errors
  pcall(vim.cmd, cmd)
end

local function relink_for_mode(match_group, group_bg, group_fg)
  local mode = vim.api.nvim_get_mode().mode
  local is_insert = (mode == 'i' or mode == 'ic')
  local link = is_insert and group_fg or group_bg
  pcall(vim.api.nvim_set_hl, 0, match_group, { default = false, link = link })
end

function M.setup(opts)
  opts = opts or {}
  local filetypes = opts.filetypes or { 'markdown' }
  local items = opts.items or {}

  if #items == 0 then
    return
  end

  local aug = vim.api.nvim_create_augroup('word_highlight_setup', { clear = false })

  vim.api.nvim_create_autocmd('ColorScheme', {
    group = aug,
    callback = function()
      for _, item in ipairs(items) do
        local _, group_bg, group_fg = create_groups(item)
        -- re-apply colors on colorscheme change
        vim.api.nvim_set_hl(0, group_bg, item.bg or { bg = '#444444', fg = '#eeeeee', bold = true })
        vim.api.nvim_set_hl(0, group_fg, item.fg or { fg = '#ff8800', bold = true })
      end
    end,
  })

  vim.api.nvim_create_autocmd('FileType', {
    group = aug,
    pattern = filetypes,
    callback = function()
      for _, item in ipairs(items) do
        local match_group, group_bg, group_fg = create_groups(item)
        ensure_syntax(item.word, match_group)
        relink_for_mode(match_group, group_bg, group_fg)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'InsertEnter', 'InsertLeave', 'ModeChanged', 'BufEnter' }, {
    group = aug,
    callback = function()
      local ft = vim.bo.filetype
      local is_target = false
      for _, p in ipairs(filetypes) do if p == ft then is_target = true break end end
      if not is_target then return end
      for _, item in ipairs(items) do
        local match_group, group_bg, group_fg = create_groups(item)
        ensure_syntax(item.word, match_group)
        relink_for_mode(match_group, group_bg, group_fg)
      end
    end,
  })
end

return M
