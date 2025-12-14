-- Generic helper for toggling line prefixes (bullets, checkboxes, etc.)
local function toggle_prefix_range(buf, sline, eline, opts, behaviour)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(buf, sline - 1, eline, false)
  local metadata = {}
  local all_have = true

  for idx, line in ipairs(lines) do
    local indent, rest = line:match("^(%s*)(.*)$")
    local has, content = behaviour.detect(rest)
    if not has then all_have = false end

    metadata[idx] = {
      indent = indent,
      has = has,
      content = content,
    }
  end

  local action
  if opts.group then
    action = all_have and "remove" or "add"
  else
    action = "toggle"
  end

  local delta_info = {}
  local changed = false
  for idx, data in ipairs(metadata) do
    local original = lines[idx]
    local new_line = original
    local delta = 0

    if action == "toggle" then
      if data.has then
        new_line, delta = behaviour.remove(data)
      else
        new_line, delta = behaviour.add(data)
      end
    elseif action == "add" then
      if not data.has then
        new_line, delta = behaviour.add(data)
      end
    elseif action == "remove" then
      if data.has then
        new_line, delta = behaviour.remove(data)
      end
    end

    if new_line ~= original then
      lines[idx] = new_line
      changed = true
    end
    delta_info[idx] = { delta = delta, indent_len = #data.indent }
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, sline - 1, eline, false, lines)
  end
  return delta_info
end

local bullet_behaviour = {
  detect = function(rest)
    if rest:sub(1, 2) == "- " then
      return true, rest:sub(3)
    end
    return false, rest
  end,
  add = function(data)
    return data.indent .. "- " .. data.content, 2
  end,
  remove = function(data)
    return data.indent .. data.content, -2
  end,
}

local function parse_checkbox(rest)
  local prefix = rest:sub(1, 6)
  if prefix == "- [ ] " then
    return true, false, rest:sub(7)
  elseif prefix == "- [x] " or prefix == "- [X] " then
    return true, true, rest:sub(7)
  end
  return false, false, rest
end

local checkbox_behaviour = {
  detect = function(rest)
    local has, _, content = parse_checkbox(rest)
    if has then return true, content end
    if rest:sub(1, 2) == "- " then
      return false, rest:sub(3)
    end
    return false, rest
  end,
  add = function(data)
    return data.indent .. "- [ ] " .. data.content, 6
  end,
  remove = function(data)
    return data.indent .. data.content, -6
  end,
}

local function toggle_bullets_range(buf, sline, eline, opts)
  return toggle_prefix_range(buf, sline, eline, opts, bullet_behaviour)
end

local function toggle_checkboxes_range(buf, sline, eline, opts)
  return toggle_prefix_range(buf, sline, eline, opts, checkbox_behaviour)
end

local function toggle_checkbox_state_range(buf, sline, eline, opts)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(buf, sline - 1, eline, false)
  local metadata = {}
  local any_checkbox = false
  local all_checked = true

  for idx, line in ipairs(lines) do
    local indent, rest = line:match("^(%s*)(.*)$")
    local has, checked, content = parse_checkbox(rest)
    if has then
      any_checkbox = true
      if not checked then all_checked = false end
    end

    metadata[idx] = {
      indent = indent,
      has = has,
      checked = checked,
      content = content,
    }
  end

  local action
  if opts.group then
    if not any_checkbox then
      return
    elseif all_checked then
      action = "uncheck"
    else
      action = "check"
    end
  else
    action = "toggle"
  end

  local changed = false
  for idx, data in ipairs(metadata) do
    local new_line = lines[idx]
    if data.has then
      if action == "check" then
        new_line = data.indent .. "- [x] " .. data.content
      elseif action == "uncheck" then
        new_line = data.indent .. "- [ ] " .. data.content
      elseif action == "toggle" then
        if data.checked then
          new_line = data.indent .. "- [ ] " .. data.content
        else
          new_line = data.indent .. "- [x] " .. data.content
        end
      end
    end
    if new_line ~= lines[idx] then
      lines[idx] = new_line
      changed = true
    end
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, sline - 1, eline, false, lines)
  end
end

local function reselect_visual_area(start_pos, end_pos, srow, delta_info)
  local delta_by_lnum = {}
  for idx, info in ipairs(delta_info) do
    delta_by_lnum[srow + idx - 1] = info
  end

  local function adjust(pos)
    local lnum = pos[2]
    local col = pos[3]
    local info = delta_by_lnum[lnum]
    if info and info.delta ~= 0 then
      local shift = info.delta
      local threshold = info.indent_len
      if shift < 0 then
        threshold = threshold - shift
      end
      if col > threshold then
        col = col + shift
        if col < 1 then col = 1 end
      end
    end
    return { pos[1], lnum, col, pos[4] }
  end

  local new_start = adjust(start_pos)
  local new_end = adjust(end_pos)

  vim.schedule(function()
    vim.fn.setpos("'<", new_start)
    vim.fn.setpos("'>", new_end)
    vim.cmd("normal! gv")
  end)
end

local function make_visual_toggle(lhs, toggler, desc)
  vim.keymap.set("x", lhs, function()
    local buf = 0
    local anchor = vim.fn.getpos("v")
    local cursor = vim.fn.getpos(".")
    local start_pos = { anchor[1], anchor[2], anchor[3], anchor[4] }
    local end_pos = { cursor[1], cursor[2], cursor[3], cursor[4] }
    local srow = math.min(anchor[2], cursor[2])
    local erow = math.max(anchor[2], cursor[2])

    local delta_info = toggler(buf, srow, erow, { group = true }) or {}
    reselect_visual_area(start_pos, end_pos, srow, delta_info)
  end, { desc = desc })
end

-- `<leader>t-` → bullets
vim.keymap.set("n", "<leader>t-", function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  toggle_bullets_range(0, row, row)
end, { desc = "Toggle bullet on current line" })

make_visual_toggle("<leader>t-", toggle_bullets_range, "Toggle bullets on selected lines (keep selection)")

-- `<leader>t[` → checkboxes
vim.keymap.set("n", "<leader>t[", function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  toggle_checkboxes_range(0, row, row)
end, { desc = "Toggle checkbox on current line" })

make_visual_toggle("<leader>t[", toggle_checkboxes_range, "Toggle checkboxes on selected lines (keep selection)")

-- `<leader>tt` → toggle checkbox state
vim.keymap.set("n", "<leader>tt", function()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  toggle_checkbox_state_range(0, row, row)
end, { desc = "Toggle checkbox state on current line" })

make_visual_toggle("<leader>tt", toggle_checkbox_state_range, "Toggle checkbox state on selected lines (keep selection)")
