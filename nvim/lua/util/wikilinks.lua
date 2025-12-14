local M = {}

local uv = vim.uv or vim.loop

local DEFAULT_VAULT_ROOT = "~/ObsidianVault"
local cached_vault_root
local vault_lookup_cache = {}
local repo_root_cache = {}

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  local expanded = path
  if expanded:sub(1, 1) == "~" then
    expanded = vim.fn.expand(expanded)
  end
  expanded = vim.fn.fnamemodify(expanded, ":p")
  if expanded:sub(-1) == "/" then
    expanded = expanded:sub(1, -2)
  end
  return expanded
end

local function get_configured_vault_root()
  if cached_vault_root == false then
    return nil
  end

  if cached_vault_root then
    return cached_vault_root
  end

  local candidate = vim.g.markdown_wikilinks_vault_root
      or vim.env.MARKDOWN_WIKILINKS_VAULT_ROOT
      or DEFAULT_VAULT_ROOT

  local normalized = normalize_path(candidate)
  if not normalized then
    cached_vault_root = false
    return nil
  end

  local stat = uv.fs_stat(normalized)
  if not stat or stat.type ~= "directory" then
    cached_vault_root = false
    return nil
  end

  cached_vault_root = normalized
  return cached_vault_root
end

local function find_repo_root(start_path)
  local normalized = normalize_path(start_path)
  if not normalized then
    return nil
  end

  local cached = repo_root_cache[normalized]
  if cached ~= nil then
    return cached or nil
  end

  if not vim.fs or not vim.fs.find then
    repo_root_cache[normalized] = false
    return nil
  end

  local matches = vim.fs.find(".git", {
    path = normalized,
    upward = true,
    limit = 1,
  })

  if matches and matches[1] then
    local git_path = normalize_path(matches[1])
    local root = git_path and normalize_path(vim.fn.fnamemodify(git_path, ":h")) or nil
    repo_root_cache[normalized] = root or false
    return root
  end

  repo_root_cache[normalized] = false
  return nil
end

local function path_in_directory(path, root)
  if not path or not root then
    return false
  end

  if #path < #root then
    return false
  end

  return path:sub(1, #root) == root
end

local function find_in_vault(root, link_path)
  if not root then
    return nil
  end

  link_path = link_path:gsub("\\", "/")

  local cache_key = root .. "::" .. link_path
  if vault_lookup_cache[cache_key] ~= nil then
    return vault_lookup_cache[cache_key]
  end

  local direct = normalize_path(root .. "/" .. link_path)
  if direct and uv.fs_stat(direct) then
    vault_lookup_cache[cache_key] = direct
    return direct
  end

  local last_component = link_path:match("([^/]+)$")
  if not last_component or last_component == "" then
    vault_lookup_cache[cache_key] = false
    return nil
  end

  local found

  if vim.fs and vim.fs.find then
    local ok, results = pcall(vim.fs.find, last_component, {
      path = root,
      type = "file",
      limit = 20,
    })
    if ok and results then
      for _, candidate in ipairs(results) do
        if candidate:sub(- #last_component) == last_component then
          found = normalize_path(candidate)
          break
        end
      end
    end
  end

  if not found then
    local escaped = vim.fn.escape(link_path, "]\\{}*? []")
    local matches = vim.fn.globpath(root, "**/" .. escaped, false, true)
    if matches and #matches > 0 then
      found = normalize_path(matches[1])
    end
  end

  if found then
    vault_lookup_cache[cache_key] = found
  end
  return found
end

local function find_company_root(path)
  local normalized = normalize_path(path)
  if not normalized then
    return nil
  end
  return normalized:match("(.*/companies/[^/]+)")
end

---Find wikilink text surrounding the 1-based column position (if any).
---@param line string|nil
---@param col integer 1-based column
---@return string|nil
function M.find_wikilink(line, col)
  if not line then
    return nil
  end

  local search_from = 1
  while true do
    local open_start = line:find("%[%[", search_from)
    if not open_start then
      return nil
    end
    local close_start, close_end = line:find("%]%]", open_start + 2)
    if not close_start then
      return nil
    end
    if col >= open_start and col <= close_end then
      return line:sub(open_start + 2, close_start - 1)
    end
    search_from = close_end + 1
  end
end

---Turn link text into a normalized markdown file path relative to the buffer.
---@param link string|nil
---@return string|nil
function M.resolve_wikilink_target(link)
  if not link then
    return nil
  end

  local sep = link:find("|")
  if sep then
    link = link:sub(1, sep - 1)
  end

  link = link:gsub("^%s+", ""):gsub("%s+$", "")
  if link == "" then
    return nil
  end

  local anchor_index = link:find("#", 1, true)
  if anchor_index then
    local base = link:sub(1, anchor_index - 1)
    if base == "" then
      return vim.fn.expand("%:p")
    end
    link = base
  end

  if not link:match("%.md$") then
    link = link .. ".md"
  end

  local first_char = link:sub(1, 1)
  local is_absolute = link:match("^[/\\]") or link:match("^%a:[/\\]")
  local is_relative = first_char ~= "~" and not is_absolute

  local current_path = normalize_path(vim.fn.expand("%:p"))
  local company_root = current_path and find_company_root(current_path) or nil
  local current_filename = current_path and current_path:match("([^/]+)$") or nil
  local company_scope_search = company_root and current_filename ~= "thesis.md"

  if company_scope_search and is_relative then
    local company_path = find_in_vault(company_root, link)
    if company_path then
      return company_path
    end
  end

  local candidates = {}

  if first_char == "~" then
    table.insert(candidates, vim.fn.expand(link))
  elseif is_absolute then
    table.insert(candidates, link)
  else
    local base_dir = vim.fn.expand("%:p:h")
    if not base_dir or base_dir == "" then
      base_dir = vim.fn.getcwd()
    end
    base_dir = normalize_path(base_dir) or base_dir
    table.insert(candidates, base_dir .. "/" .. link)

    local repo_root = find_repo_root(base_dir)
    if repo_root and repo_root ~= base_dir then
      table.insert(candidates, repo_root .. "/" .. link)
    end
  end

  if #candidates == 0 then
    table.insert(candidates, link)
  end

  local normalized_candidates = {}
  local seen = {}
  for _, candidate in ipairs(candidates) do
    local absolute = vim.fn.simplify(vim.fn.fnamemodify(candidate, ":p"))
    if not seen[absolute] then
      table.insert(normalized_candidates, absolute)
      seen[absolute] = true
    end
  end

  local path = normalized_candidates[1]
  for _, candidate in ipairs(normalized_candidates) do
    if uv.fs_stat(candidate) then
      path = candidate
      break
    end
  end

  if not path then
    return nil
  end

  local vault_root
  local configured_root = get_configured_vault_root()
  if configured_root and current_path and path_in_directory(current_path, configured_root) then
    vault_root = configured_root
  end

  if vault_root and is_relative then
    local global = find_in_vault(vault_root, link)
    if global then
      return global
    end
  end

  return path
end

---Create ancestor directories when opening a new wiki note.
---@param path string
function M.ensure_parent_directory(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" and dir ~= "." and vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

---@param path string
---@return boolean
function M.wikilink_exists(path)
  return uv.fs_stat(path) ~= nil
end

---Find the deepest wikilink start before the cursor that is still open.
---Returns the 1-based position of the first '[' in '[[', or nil.
---@param line string
---@param cursor_col0 integer 0-based byte column from context.cursor[2]
---@return integer|nil
function M.find_open_wikilink(line, cursor_col0)
  local cursor_col1 = cursor_col0 + 1
  local search_from = 1
  local last_open
  while true do
    local open_start = line:find("[[", search_from, true)
    if not open_start or open_start >= cursor_col1 then
      break
    end
    local close_start = line:find("]]", open_start + 2, true)
    if not close_start or close_start >= cursor_col1 then
      last_open = open_start
    end
    search_from = open_start + 1
  end
  return last_open
end

---List markdown files under the provided directory, returning relative paths with the extension trimmed.
---@param base_dir string
---@param opts? { extension?: string, max_items?: integer, max_results?: integer, allow_hidden?: boolean, filter?: fun(relative: string, absolute: string): boolean }
---@return string[]
function M.list_markdown_files(base_dir, opts)
  opts = opts or {}
  local extension = opts.extension or ".md"
  local max_results = opts.max_results or opts.max_items or math.huge
  local allow_hidden = opts.allow_hidden or false
  local filter_fn = opts.filter

  local results = {}

  local function scan(dir, prefix)
    if #results >= max_results then
      return
    end

    local handle = uv.fs_scandir(dir)
    if not handle then
      return
    end

    while true do
      local name, typ = uv.fs_scandir_next(handle)
      if not name then
        break
      end

      if not allow_hidden and name:sub(1, 1) == "." then
        goto continue
      end

      local child = dir .. "/" .. name
      if typ == "directory" then
        scan(child, prefix .. name .. "/")
        if #results >= max_results then
          break
        end
      elseif typ == "file" then
        if extension == "" or name:sub(- #extension) == extension then
          local relative = prefix .. name
          if extension ~= "" and relative:sub(- #extension) == extension then
            relative = relative:sub(1, #relative - #extension)
          end
          local absolute = child
          if not filter_fn or filter_fn(relative, absolute) then
            table.insert(results, relative)
            if #results >= max_results then
              break
            end
          end
        end
      end

      ::continue::
    end
  end

  scan(base_dir, "")
  table.sort(results)
  return results
end

return M
