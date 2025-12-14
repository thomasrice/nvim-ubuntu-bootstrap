-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Helper for termcodes

-- [NORMAL] Ctrl-k --> change word to a Wikilink

require("config.make")


local format_group = vim.api.nvim_create_augroup("python_format_on_save", { clear = true })

local function organize_python_imports(bufnr)
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("conform.nvim is not available", vim.log.levels.ERROR)
    return
  end

  conform.format({
    bufnr = bufnr,
    async = false,
    formatters = { "isort" },
    lsp_fallback = false,
    timeout_ms = 5000,
  })
end

local spell_ignore_group = vim.api.nvim_create_augroup("ignore_spell_patterns", { clear = true })

local python_indent_group = vim.api.nvim_create_augroup("python_indent", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = python_indent_group,
  pattern = "python",
  callback = function(event)
    -- Python style guide expects 4-space indents even though the global default is 2
    vim.bo[event.buf].tabstop = 4
    vim.bo[event.buf].softtabstop = 4
    vim.bo[event.buf].shiftwidth = 4
  end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
  group = spell_ignore_group,
  callback = function(event)
    if vim.api.nvim_buf_get_option(event.buf, "buftype") ~= "" then
      return
    end

    vim.api.nvim_buf_call(event.buf, function()
      if vim.b.custom_spell_ignore_applied then
        return
      end

      vim.b.custom_spell_ignore_applied = true

      local url_pattern =
      [=[syntax match SpellNoSpellUrl /\<\w\+:\/\/[^ \t\r\n<>()\[\]]\+/ contains=@NoSpell containedin=ALL keepend]=]
      local email_pattern =
      [=[syntax match SpellNoSpellEmail /\<[[:alnum:]._%+-]\+@[[:alnum:].-]\+\.[[:alpha:]]\{2,}/ contains=@NoSpell containedin=ALL keepend]=]

      pcall(vim.cmd, url_pattern)
      pcall(vim.cmd, email_pattern)
      pcall(vim.cmd, "syntax cluster NoSpell add=SpellNoSpellUrl")
      pcall(vim.cmd, "syntax cluster NoSpell add=SpellNoSpellEmail")
    end)
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  group = format_group,
  pattern = "*.py",
  callback = function(event)
    if vim.api.nvim_buf_get_option(event.buf, "buftype") ~= "" then
      return
    end

    local ok, conform = pcall(require, "conform")
    if not ok then
      return
    end

    conform.format({
      bufnr = event.buf,
      async = false,
      formatters = { "isort", "black" },
      lsp_fallback = false,
      timeout_ms = 5000,
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = format_group,
  pattern = "python",
  callback = function(event)
    vim.keymap.set("n", "<leader>co", function()
      organize_python_imports(event.buf)
    end, { buffer = event.buf, desc = "Organise imports (isort)" })
  end,
})

local cursor_highlight_group = vim.api.nvim_create_augroup("custom_cursor_highlight", { clear = true })

local function set_insert_cursor_highlight()
  vim.api.nvim_set_hl(0, "CursorInsert", { fg = "#000000", bg = "#00ffff" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = cursor_highlight_group,
  callback = set_insert_cursor_highlight,
})

if vim.g.colors_name then
  set_insert_cursor_highlight()
end

local markdown_highlight_group = vim.api.nvim_create_augroup("custom_markdown_highlight", { clear = true })

local function set_markdown_bold_highlight()
  local bold_colour = "#32CD32"
  for _, group in ipairs({
    "@markup.strong",
    "@markup.strong.markdown",
    "@markup.strong.markdown_inline",
    "markdownBold",
    "RenderMarkdownStrong",
    "RenderMarkdownInlineStrong",
  }) do
    pcall(vim.api.nvim_set_hl, 0, group, { fg = bold_colour, bold = true })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = markdown_highlight_group,
  callback = function()
    set_markdown_bold_highlight()
  end,
})

if vim.g.colors_name then
  set_markdown_bold_highlight()
end

local wiki_group = vim.api.nvim_create_augroup("markdown_wikilinks", { clear = true })
local wikilinks_ui = require("util.wikilinks_ui")
local autocomplete_lists = require("util.autocomplete_lists")

vim.api.nvim_create_autocmd("ColorScheme", {
  group = wiki_group,
  callback = function()
    wikilinks_ui.set_highlights()
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = wiki_group,
  pattern = { "markdown", "markdown.mdx", "markdown.pandoc" },
  callback = function(event)
    wikilinks_ui.attach_buffer(event.buf)
  end,
})

local autocomplete_group = vim.api.nvim_create_augroup("project_autocomplete_buffers", { clear = true })
local autocomplete_filename = "_autocomplete.md"
local uv = vim.uv or vim.loop

local function find_autocomplete_file(file)
  if not file or file == "" then
    return nil
  end

  local dir = vim.fs.dirname(file)
  if not dir or dir == "" then
    return nil
  end

  local function check(path)
    local candidate = vim.fs.joinpath(path, autocomplete_filename)
    local stat = uv.fs_stat(candidate)
    if stat and stat.type == "file" then
      return candidate
    end
  end

  local candidate = check(dir)
  if candidate then
    return candidate
  end

  for parent in vim.fs.parents(dir) do
    candidate = check(parent)
    if candidate then
      return candidate
    end
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = autocomplete_group,
  callback = function(event)
    if vim.api.nvim_buf_get_option(event.buf, "buftype") ~= "" then
      vim.b[event.buf].project_autocomplete_file = nil
      return
    end

    local file = vim.api.nvim_buf_get_name(event.buf)
    local autocomplete_file = find_autocomplete_file(file)
    autocomplete_file = autocomplete_lists.normalize(autocomplete_file)
    vim.b[event.buf].project_autocomplete_file = autocomplete_file
    if autocomplete_file then
      autocomplete_lists.get_words(autocomplete_file)
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = autocomplete_group,
  pattern = "**/" .. autocomplete_filename,
  callback = function(event)
    local path = vim.api.nvim_buf_get_name(event.buf)
    if path == "" then
      path = event.match
    end
    autocomplete_lists.invalidate(path)
  end,
})
