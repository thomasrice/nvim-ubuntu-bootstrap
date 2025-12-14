local Kind = require("blink.cmp.types").CompletionItemKind
local wiki = require("util.wikilinks")

local uv = vim.uv or vim.loop

---@class WikilinkCompletionSource
---@field opts { extension: string, max_items: integer, allow_hidden: boolean }
---@field cache table<string, { mtime: string, items: string[] }>
local Source = {}
Source.__index = Source

---@param opts? table
---@return WikilinkCompletionSource
function Source.new(opts)
  opts = opts or {}

  local extension = opts.extension or ".md"
  local max_items = opts.max_items -- nil means unlimited
  local allow_hidden = opts.allow_hidden or false
  local search_limit = opts.search_limit or 400

  local self = setmetatable({
    opts = {
      extension = extension,
      max_items = max_items,
      allow_hidden = allow_hidden,
      search_limit = search_limit,
    },
    cache = {},
  }, Source)

  return self
end

function Source:enabled()
  return true
end

function Source:get_trigger_characters()
  return { "[", "/", "\\" }
end

---@param context blink.cmp.Context
---@param callback fun(result?: blink.cmp.CompletionResponse)
function Source:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local link_context = self:_current_link_context(context)
  if not link_context then
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return
  end

  local items = self:_build_items(link_context)
  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

---@param context blink.cmp.Context
---@param item blink.cmp.CompletionItem
---@param resolve fun()
---@param default_implementation fun(context?: blink.cmp.Context, item?: blink.cmp.CompletionItem)
function Source:execute(_, _, resolve, default_implementation)
  default_implementation()

  vim.schedule(function()
    local row, col0 = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local search_start = col0 + 1
    local closing = line:find("]]", search_start, true)
    if closing then
      local new_col0 = closing + 1
      if new_col0 > #line then
        new_col0 = #line
      end
      vim.api.nvim_win_set_cursor(0, { row, new_col0 })
    end
    resolve()
  end)
end

---@param context blink.cmp.Context
---@return { range: lsp.Range, prefix: string, base_dir: string }|nil
function Source:_current_link_context(context)
  local line = context.line
  if not line or line == "" then
    return nil
  end

  local cursor_col0 = context.cursor[2]
  local cursor_col1 = cursor_col0 + 1
  local open_start = wiki.find_open_wikilink(line, cursor_col0)
  if not open_start then
    return nil
  end

  local content_start_index = open_start + 2
  if cursor_col0 < content_start_index - 1 then
    return nil
  end

  local before_cursor = ""
  local end_index = cursor_col1 - 1
  if end_index >= content_start_index then
    before_cursor = line:sub(content_start_index, end_index)
  end
  if before_cursor:find("|", 1, true) or before_cursor:find("#", 1, true) then
    return nil
  end

  local bufname = vim.api.nvim_buf_get_name(context.bufnr)
  if bufname == "" then
    return nil
  end

  local base_dir = vim.fs.dirname(bufname)
  if not base_dir or base_dir == "" then
    return nil
  end

  local range = {
    start = {
      line = context.cursor[1] - 1,
      character = content_start_index - 1,
    },
    ["end"] = {
      line = context.cursor[1] - 1,
      character = cursor_col0,
    },
  }

  return {
    range = range,
    prefix = before_cursor,
    base_dir = base_dir,
  }
end

---@param link_context { range: lsp.Range, prefix: string, base_dir: string }
---@return blink.cmp.CompletionItem[]
function Source:_build_items(link_context)
  local prefix = link_context.prefix or ""
  local candidates = self:_get_candidates(link_context.base_dir)
  if prefix ~= "" then
    candidates = self:_filter_candidates(candidates, prefix:lower())
    if not candidates or #candidates == 0 then
      candidates = self:_get_candidates(link_context.base_dir)
    end
  end
  if not candidates or #candidates == 0 then
    return {}
  end

  local prefix_lower = prefix:lower()
  local items = {}

  local function compute_score(idx)
    if prefix_lower == "" then
      return 0
    end
    if idx == 1 then
      return 240
    elseif idx and idx > 0 then
      return math.max(0, 160 - (idx - 1) * 10)
    end
    return 0
  end

  for _, candidate in ipairs(candidates) do
    local label = candidate
    local candidate_lower = label:lower()

    local match_index
    if prefix_lower == "" then
      match_index = 1
    else
      match_index = candidate_lower:find(prefix_lower, 1, true)
    end

    if prefix_lower == "" or match_index ~= nil then
      local score_offset = compute_score(match_index)
      local sort_key = string.format("%04d_%s", match_index or 9999, candidate_lower)

      table.insert(items, {
        label = label,
        filterText = label,
        sortText = sort_key,
        score_offset = score_offset,
        textEdit = {
          range = link_context.range,
          newText = label,
        },
        kind = Kind.File,
        data = {
          base_dir = link_context.base_dir,
          relative_path = candidate,
        },
      })
    end
  end

  return items
end

---@param base_dir string
---@return string[]
function Source:_get_candidates(base_dir)
  local stat = uv.fs_stat(base_dir)
  if not stat then
    return {}
  end

  local mtime = stat.mtime and (stat.mtime.sec .. ":" .. stat.mtime.nsec) or ""
  local entry = self.cache[base_dir]
  if entry and entry.mtime == mtime then
    return entry.items
  end

  local items = wiki.list_markdown_files(base_dir, {
    extension = self.opts.extension,
    max_results = self.opts.max_items,
    allow_hidden = self.opts.allow_hidden,
  })

  self.cache[base_dir] = {
    mtime = mtime,
    items = items,
  }

  return items
end

---@param candidates string[]
---@param prefix_lower string
---@return string[]
function Source:_filter_candidates(candidates, prefix_lower)
  if not candidates or prefix_lower == "" then
    return candidates
  end

  local filtered = {}
  local limit = self.opts.search_limit or 400
  for _, candidate in ipairs(candidates) do
    if candidate:lower():find(prefix_lower, 1, true) then
      table.insert(filtered, candidate)
      if #filtered >= limit then
        break
      end
    end
  end

  return filtered
end

return Source
