local Kind = require("blink.cmp.types").CompletionItemKind
local lists = require("util.autocomplete_lists")

---@class ProjectAutocompleteSource
---@field opts { score_offset: integer }
local Source = {}
Source.__index = Source

local function apply_case(word, keyword)
  if not keyword or keyword == "" or not word or word == "" then
    return word
  end

  local typed = keyword:sub(1, 1)
  local target = word:sub(1, 1)

  if not typed:match("%a") or not target:match("%a") then
    return word
  end

  if typed:match("%l") then
    return target:lower() .. word:sub(2)
  elseif typed:match("%u") then
    return target:upper() .. word:sub(2)
  end

  return word
end

local function contains_substring(text, keyword)
  if not keyword or keyword == "" then
    return true
  end
  if not text or text == "" then
    return false
  end
  return text:lower():find(keyword:lower(), 1, true) ~= nil
end

local function get_replace_range(context)
  local bounds = context and context.bounds
  if not bounds then
    return nil
  end

  return {
    start = {
      line = bounds.line_number - 1,
      character = bounds.start_col - 1,
    },
    ["end"] = {
      line = bounds.line_number - 1,
      character = bounds.start_col - 1 + bounds.length,
    },
  }
end

---@param opts? table
---@return ProjectAutocompleteSource
function Source.new(opts)
  opts = opts or {}
  return setmetatable({
    opts = {
      score_offset = opts.score_offset or 10,
    },
  }, Source)
end

function Source:enabled()
  return true
end

---@param _ blink.cmp.Context
function Source:get_trigger_characters(_)
  return {}
end

---@param context blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
function Source:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local buf = context.bufnr
  if not buf then
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return
  end

  local autocomplete_file = vim.b[buf] and vim.b[buf].project_autocomplete_file
  if not autocomplete_file then
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return
  end

  local words = lists.get_words(autocomplete_file)
  if not words or #words == 0 then
    callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    return
  end

  local keyword = context.get_keyword and context:get_keyword() or ""
  keyword = vim.trim(keyword or "")
  keyword = keyword:match("([%w_'%-]+)$") or keyword

  if keyword ~= "" then
    local filtered = {}
    for _, word in ipairs(words) do
      if contains_substring(word, keyword) then
        filtered[#filtered + 1] = word
      end
    end
    words = filtered
    if #words == 0 then
      callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
      return
    end
  end
  local replace_range = get_replace_range(context)

  local items = {}
  for _, word in ipairs(words) do
    local insert = apply_case(word, keyword)
    local item = {
      label = word,
      filterText = word,
      insertText = insert,
      kind = Kind.Text,
      score_offset = self.opts.score_offset,
      detail = "[Project]",
    }
    if replace_range then
      item.textEdit = {
        range = replace_range,
        newText = insert,
      }
    end
    items[#items + 1] = item
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return Source
