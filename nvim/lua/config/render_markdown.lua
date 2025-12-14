-- Markdown Style overrides
-- https://github.com/MeanderingProgrammer/render-markdown.nvim

-- === Colour Triads ===
-- Cyan family
local dark_cyan    = "#1e5860"
local cyan         = "#48b0bd"
local light_cyan   = "#00EFEF"

-- Purple family
local dark_purple  = "#5d2d72"
local purple       = "#bf68d9"
local light_purple = "#dba6f2"

-- Yellow / Gold family
local dark_yellow  = "#6a4e12"
local yellow       = "#e2b86b"
local light_yellow = "#f3d89a"

-- Red family
local dark_red     = "#702a2a"
local red          = "#e55561"
local light_red    = "#ff7a84"

-- Blue family
local dark_blue    = "#102c47"
local blue         = "#4fa6ed"
local light_blue   = "#8ccfff"

-- Green family
local dark_green   = "#1e3a23"
local green        = "#8ebd6b"
local light_green  = "#b7e69a"


local heading_styles = {
  {
    block = "RenderMarkdownH1Bg",
    block_opts = { bg = dark_cyan, fg = light_cyan, bold = true },
    ts = "@markup.heading.1.markdown",
    ts_opts = { fg = light_cyan, bold = true },
  },
  {
    block = "RenderMarkdownH2Bg",
    block_opts = { bg = dark_purple, fg = light_purple, bold = true },
    ts = "@markup.heading.2.markdown",
    ts_opts = { fg = purple, bold = true },
  },
  {
    block = "RenderMarkdownH3Bg",
    block_opts = { bg = dark_red, fg = light_red, bold = true },
    ts = "@markup.heading.3.markdown",
    ts_opts = { fg = red, bold = true },
  },
  {
    block = "RenderMarkdownH4Bg",
    block_opts = { bg = dark_green, fg = light_green, bold = true },
    ts = "@markup.heading.4.markdown",
    ts_opts = { fg = green, bold = true },
  },
  {
    block = "RenderMarkdownH5Bg",
    block_opts = { bg = dark_blue, fg = light_blue, bold = true },
    ts = "@markup.heading.5.markdown",
    ts_opts = { fg = blue, bold = true },
  },
  {
    block = "RenderMarkdownH6Bg",
    block_opts = { bg = dark_yellow, fg = light_yellow, bold = true },
    ts = "@markup.heading.6.markdown",
    ts_opts = { fg = yellow, bold = true },
  },
}

local function set_heading_highlights()
  for _, heading in ipairs(heading_styles) do
    vim.api.nvim_set_hl(0, heading.block, heading.block_opts)
    vim.api.nvim_set_hl(0, heading.ts, heading.ts_opts)
  end
end

set_heading_highlights()

local heading_aug = vim.api.nvim_create_augroup("render_markdown_heading_highlight", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = heading_aug,
  callback = function()
    set_heading_highlights()
  end,
})

-- Treesitter treats content between tildes as strikethrough, which clashes
-- with approximate numbers like ~20m. Clear the highlight so no strike is shown.
local function disable_strikethrough_highlight()
  local groups = {
    "@markup.strikethrough",
    "@markup.strikethrough.markdown",
    "@markup.strikethrough.markdown_inline",
  }
  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { strikethrough = false })
  end
end

disable_strikethrough_highlight()

local strike_aug = vim.api.nvim_create_augroup("render_markdown_disable_strike", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = strike_aug,
  callback = disable_strikethrough_highlight,
})

-- Mode-aware blockquote background for lines starting with '>'
local quote_styles = {
  normal = { bg = dark_blue, fg = light_blue, bold = false },
  insert = { bg = dark_blue, fg = light_blue, bold = false },
}

local quote_groups = {
  normal = 'RenderMarkdownQuoteNormal',
  insert = 'RenderMarkdownQuoteInsert',
}

local quote_namespace = vim.api.nvim_create_namespace('render_markdown_quote_ns')
local quote_filetypes = { 'markdown', 'markdown.mdx', 'markdown.pandoc' }

local function set_quote_highlight_groups()
  for mode, group in pairs(quote_groups) do
    local style = quote_styles[mode]
    if style then
      vim.api.nvim_set_hl(0, group, style)
    end
  end
end

local function is_quote_buffer(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  for _, name in ipairs(quote_filetypes) do
    if ft == name then
      return true
    end
  end
  return false
end

local function current_quote_group()
  local mode = vim.api.nvim_get_mode().mode
  local is_insert = mode:sub(1, 1) == 'i'
  return is_insert and quote_groups.insert or quote_groups.normal
end

local function apply_quote_highlights(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not is_quote_buffer(bufnr) then
    return
  end

  local group = current_quote_group()
  if not group then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, quote_namespace, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for idx, line in ipairs(lines) do
    local first_non_space = line:find('%S')
    if first_non_space and line:sub(first_non_space, first_non_space) == '>' then
      vim.api.nvim_buf_add_highlight(bufnr, quote_namespace, group, idx - 1, first_non_space - 1, -1)
    end
  end
end

set_quote_highlight_groups()

local quote_aug = vim.api.nvim_create_augroup('render_markdown_quote_highlight', { clear = true })

vim.api.nvim_create_autocmd('ColorScheme', {
  group = quote_aug,
  callback = function()
    set_quote_highlight_groups()
    apply_quote_highlights()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = quote_aug,
  pattern = quote_filetypes,
  callback = function(event)
    set_quote_highlight_groups()
    apply_quote_highlights(event.buf)
  end,
})

vim.api.nvim_create_autocmd({ 'BufEnter', 'TextChanged', 'TextChangedI', 'InsertEnter', 'InsertLeave', 'ModeChanged' }, {
  group = quote_aug,
  callback = function(event)
    apply_quote_highlights(event.buf)
  end,
})

apply_quote_highlights()

-- Word highlighters (syntax-based, mode-aware)
local wordhl = require('util.word_highlight')
wordhl.setup({
  filetypes = { 'markdown', 'markdown.mdx', 'markdown.pandoc' },
  items = {
    {
      word = 'WAITING',
      bg = { bg = '#7a3e00', fg = '#fff7ed', bold = true },
      fg = { fg = '#f59e0b', bold = true },
    },
    {
      word = 'CODING',
      bg = { bg = '#163c3b', fg = '#39e6e1', bold = true },
      fg = { fg = '#39e6e1', bold = true },
    },
    {
      word = 'BUG',
      bg = { bg = '#9c0c3e', fg = '#ffffff', bold = true },
      fg = { fg = '#d34a69', bold = true },
    },
    {
      word = 'REFACTOR',
      bg = { bg = '#163c3b', fg = '#39e6e1', bold = true },
      fg = { fg = '#39e6e1', bold = true },
    },
    {
      word = 'FEATURE',
      bg = { bg = '#163c3b', fg = '#39e6e1', bold = true },
      fg = { fg = '#39e6e1', bold = true },
    },
  },
})
