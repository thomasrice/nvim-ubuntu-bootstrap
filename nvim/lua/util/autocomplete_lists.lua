local uv = vim.uv or vim.loop

local M = {}

local cache = {}

local function normalize(path)
  if not path or path == "" then
    return nil
  end

  if path:sub(1, 1) == "~" then
    path = vim.fn.expand(path)
  end

  path = vim.fn.fnamemodify(path, ":p")
  if path:sub(-1) == "/" then
    path = path:sub(1, -2)
  end

  return path
end

local function cache_key(stat)
  if not stat then
    return nil
  end
  if type(stat.mtime) == "table" then
    return string.format("%d:%d", stat.mtime.sec or 0, stat.mtime.nsec or 0)
  end
  return tostring(stat.mtime or "")
end

local function parse_lines(lines)
  local seen, words = {}, {}
  for _, line in ipairs(lines or {}) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      local entry = trimmed:gsub("^[-*]%s+", "", 1)
      entry = vim.trim(entry)
      if entry ~= "" and not seen[entry] then
        seen[entry] = true
        words[#words + 1] = entry
      end
    end
  end
  return words
end

function M.normalize(path)
  return normalize(path)
end

function M.invalidate(path)
  path = normalize(path)
  if path then
    cache[path] = nil
  end
end

function M.get_words(path)
  path = normalize(path)
  if not path then
    return nil
  end

  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    cache[path] = nil
    return nil
  end

  local key = cache_key(stat)
  local entry = cache[path]
  if entry and entry.key == key then
    return entry.words
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  local words = ok and parse_lines(lines) or {}
  cache[path] = {
    key = key,
    words = words,
  }
  return words
end

return M
