-- Continue markdown bullet lists when pressing <CR>
vim.opt_local.formatoptions:append("r")
vim.opt_local.formatoptions:append("o")

for _, marker in ipairs({ "b:-", "b:*", "b:+" }) do
  vim.opt_local.comments:append(marker)
end

local newline = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
local ctrl_u = vim.api.nvim_replace_termcodes("<C-u>", true, false, true)

local function trim(str)
  str = str:gsub("^%s+", "")
  return str:gsub("%s+$", "")
end

vim.keymap.set("i", "<CR>", function()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local col = cursor[2]
  local line = vim.api.nvim_get_current_line()

  if col < #line then
    return newline
  end

  local indent, marker, spacing, rest = line:match("^(%s*)([%-%*+])(%s+)(.*)$")
  if not marker then
    return newline
  end

  local checkbox = rest:match("^%[[ xX%-]%]%s*") or ""
  local remainder = rest:sub(#checkbox + 1)

  if trim(remainder) == "" then
    return newline .. ctrl_u .. indent
  end

  local leader = indent .. marker .. spacing .. checkbox
  return newline .. ctrl_u .. leader
end, { buffer = true, expr = true, replace_keycodes = false })
