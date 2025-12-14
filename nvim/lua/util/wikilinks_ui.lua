local wiki = require("util.wikilinks")

local M = {}

M.colors = {
  --  existing = "#3c6aff",
  existing = "#59F5F8",
  missing = "#8c41f7",
  external = "#f5dd52", -- default to Catppuccin lavender for regular markdown links
}

local ns = vim.api.nvim_create_namespace("markdown_wikilinks_highlight")
local pending_refresh = {}

local function set_wiki_highlights()
  vim.api.nvim_set_hl(0, "MarkdownWikiLink", {
    default = false,
    fg = M.colors.existing,
    underline = false,
  })
  vim.api.nvim_set_hl(0, "MarkdownWikiLinkExisting", {
    default = false,
    fg = M.colors.existing,
    underline = false,
  })
  vim.api.nvim_set_hl(0, "MarkdownWikiLinkExistingIcon", {
    default = false,
    fg = M.colors.existing,
    underline = false
  })
  vim.api.nvim_set_hl(0, "MarkdownWikiLinkMissing", {
    default = false,
    fg = M.colors.missing,
    underline = false,
  })
  vim.api.nvim_set_hl(0, "MarkdownWikiLinkMissingIcon", {
    default = false,
    fg = M.colors.missing,
    underline = false
  })

  -- External/regular markdown links (render-markdown + treesitter)
  vim.api.nvim_set_hl(0, "RenderMarkdownLink", {
    default = false,
    fg = M.colors.external,
    underline = false,
  })
  vim.api.nvim_set_hl(0, "@markup.link.label.markdown_inline", {
    default = false,
    fg = M.colors.external,
    underline = false,
  })
end

M.set_highlights = set_wiki_highlights

local function refresh_wikilink_highlights(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for idx, line in ipairs(lines) do
    local search_from = 1
    while true do
      local open_start = line:find("[[", search_from, true)
      if not open_start then
        break
      end
      local close_start = line:find("]]", open_start + 2, true)
      if not close_start then
        break
      end

      local contents = line:sub(open_start + 2, close_start - 1)
      local target = wiki.resolve_wikilink_target(contents)
      local exists = target and wiki.wikilink_exists(target)
      local hl_group = exists and "MarkdownWikiLinkExisting" or "MarkdownWikiLinkMissing"
      local icon_hl = exists and "MarkdownWikiLinkExistingIcon" or "MarkdownWikiLinkMissingIcon"
      local icon_text = ""

      -- Use an extmark for both the highlight and optional inline icon so it
      -- wins over Treesitter/theme highlights.
      vim.api.nvim_buf_set_extmark(buf, ns, idx - 1, open_start - 1, {
        end_row = idx - 1,
        end_col = close_start + 1,
        hl_group = hl_group,
        hl_mode = "replace", -- force our fg/bg to override theme/treesitter
        virt_text = { { icon_text, icon_hl } },
        virt_text_pos = "inline",
        priority = 2000,
      })

      search_from = close_start + 2
    end
  end
end

function M.schedule_refresh(buf)
  if pending_refresh[buf] then
    pending_refresh[buf]:stop()
    pending_refresh[buf]:close()
    pending_refresh[buf] = nil
  end

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      refresh_wikilink_highlights(buf)
    end
  end)
end

local function maybe_show_wikilink_completions(buf)
  local ok_cmp, cmp = pcall(require, "blink.cmp")
  if not ok_cmp or not cmp.show then
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "i" and mode ~= "ic" then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_col0 = cursor[2]
  local cursor_col1 = cursor_col0 + 1
  local line = vim.api.nvim_get_current_line()
  local open_start = wiki.find_open_wikilink(line, cursor_col0)
  if not open_start then
    return
  end

  local content_start_index = open_start + 2
  if cursor_col0 < content_start_index - 1 then
    return
  end

  local before_cursor = ""
  local end_index = cursor_col1 - 1
  if end_index >= content_start_index then
    before_cursor = line:sub(content_start_index, end_index)
  end

  if before_cursor:find("|", 1, true) or before_cursor:find("#", 1, true) then
    return
  end

  local is_wiki_visible = false
  if cmp.is_visible() then
    local ok_list, list = pcall(require, "blink.cmp.completion.list")
    if ok_list and list.items then
      for _, item in ipairs(list.items) do
        if item.source_id == "wikilinks" then
          is_wiki_visible = true
          break
        end
      end
    end
    if is_wiki_visible then
      return
    end
  end

  cmp.show({ providers = { "wikilinks" }, initial_selected_item_idx = 1 })
  M.schedule_refresh(buf)
end

local function open_wikilink_or_default(buf)
  local _, col0 = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local col1 = col0 + 1

  local function trim_trailing_punctuation(text)
    return text:gsub([[[]>)}%],.;!?'\"]+$]], "")
  end

  local uv = vim.uv or vim.loop

  local function open_external_target(target)
    if target == nil or target == "" then
      return false
    end

    local original = target
    if target:match("^www%.") then
      target = "https://" .. target
    end

    if target:match("^[%w%-%._~:/%?#%[%]@!$&'()*+,;=]+$") then
      -- treat bare paths as files
      local path = target
      if not path:match("^%w+://") then
        path = vim.fn.fnamemodify(path, ":p")
        if uv.fs_stat(path) then
          vim.cmd({ cmd = "edit", args = { path } })
          return true
        end
      end
    end

    local function try_vim_ui()
      local ok, result = pcall(function()
        if vim.ui and vim.ui.open then
          return vim.ui.open(target)
        end
        return false
      end)
      return ok and result ~= false
    end

    if try_vim_ui() then
      return true
    end

    local cmd
    if vim.fn.has("win32") == 1 then
      cmd = { "cmd.exe", "/c", "start", "", target }
    elseif vim.fn.has("mac") == 1 then
      cmd = { "open", target }
    else
      cmd = { "xdg-open", target }
    end

    local job = vim.fn.jobstart(cmd, { detach = true })
    if job > 0 then
      return true
    end

    vim.notify("Unable to open link: " .. original, vim.log.levels.WARN)
    return false
  end

  local function open_markdown_link()
    local line_len = #line
    local search_from = 1
    while true do
      local text_start = line:find("[", search_from, true)
      if not text_start then
        break
      end

      local text_end = line:find("]", text_start + 1, true)
      if not text_end then
        break
      end

      local target_open = text_end + 1
      while target_open <= line_len do
        local ws = line:sub(target_open, target_open)
        if ws ~= " " and ws ~= "\t" then
          break
        end
        target_open = target_open + 1
      end

      if target_open > line_len or line:sub(target_open, target_open) ~= "(" then
        search_from = text_start + 1
        goto continue
      end

      local depth = 1
      local target_close = target_open
      while target_close < line_len and depth > 0 do
        target_close = target_close + 1
        local ch = line:sub(target_close, target_close)
        if ch == "(" then
          depth = depth + 1
        elseif ch == ")" then
          depth = depth - 1
        end
      end

      if depth ~= 0 then
        break
      end

      if col1 >= text_start and col1 <= target_close then
        local target = line:sub(target_open + 1, target_close - 1)
        target = target:gsub("^%s+", ""):gsub("%s+$", "")
        if target ~= "" then
          return open_external_target(target)
        end
        return false
      end

      search_from = target_close + 1

      ::continue::
    end

    return false
  end

  local function open_plain_link()
    local uri_charset = "[%w%-%._~:/%?#%[%]@!$&'()*+,;=]"
    local patterns = {
      "https?://" .. uri_charset .. "+",
      "file://" .. uri_charset .. "+",
      "mailto:" .. uri_charset .. "+",
      "www%." .. uri_charset .. "+",
    }

    for _, pattern in ipairs(patterns) do
      local search_from = 1
      while true do
        local start_idx, end_idx = line:find(pattern, search_from)
        if not start_idx then
          break
        end
        if col1 >= start_idx and col1 <= end_idx then
          local target = trim_trailing_punctuation(line:sub(start_idx, end_idx))
          return open_external_target(target)
        end
        if start_idx > col1 then
          break
        end
        search_from = end_idx + 1
      end
    end

    return false
  end

  local link = wiki.find_wikilink(line, col1)
  if not link then
    if open_markdown_link() then
      return
    end
    open_plain_link()
    return
  end

  local path = wiki.resolve_wikilink_target(link)
  if not path then
    vim.notify("Invalid wikilink", vim.log.levels.WARN)
    return
  end

  local exists = wiki.wikilink_exists(path)
  if not exists then
    wiki.ensure_parent_directory(path)
  end

  vim.cmd({ cmd = "edit", args = { path } })

  if not exists then
    vim.notify("Creating wiki file: " .. path, vim.log.levels.INFO)
  end
  M.schedule_refresh(buf)
end

local function apply_syntax_match(buf)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd([=[syntax match MarkdownWikiLink /\v\[\[[^|\]]+(\|[^\]]+)?\]\]/ containedin=ALL]=])
  end)
end

function M.attach_buffer(buf)
  apply_syntax_match(buf)
  set_wiki_highlights()

  local group = vim.api.nvim_create_augroup("markdown_wikilinks_buf_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "TextChangedP", "InsertLeave" }, {
    group = group,
    buffer = buf,
    desc = "Refresh wikilink highlights",
    callback = function()
      M.schedule_refresh(buf)
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = group,
    buffer = buf,
    desc = "Show wikilink completions",
    callback = function()
      vim.schedule(function()
        maybe_show_wikilink_completions(buf)
      end)
    end,
  })

  vim.keymap.set("n", "gx", function()
    open_wikilink_or_default(buf)
  end, {
    buffer = buf,
    desc = "Open wiki link",
    silent = true,
  })

  vim.keymap.set("n", "<C-CR>", "gx", {
    buffer = buf,
    desc = "Open wiki link",
    remap = true,
  })

  M.schedule_refresh(buf)
end

return M
