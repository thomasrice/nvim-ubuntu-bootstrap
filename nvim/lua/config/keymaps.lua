-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.toggles")

-- How to write shortcuts
--
-- One line -- "iab" is "insert abbreviation" would replace "sti " with the remainder

vim.keymap.set("i", "<S-Tab>", "<C-d", { desc = "Outdent" })

-- Yank
vim.keymap.set('n', '<leader>yf', function() vim.fn.setreg('+', vim.fn.expand('%:t')) end, { desc = 'Yank file name' })
-- Yank path relative to current working directory (Neovim CWD)
vim.keymap.set('n', '<leader>yp', function()
  local buf_path = vim.fn.expand('%:p')
  if buf_path == '' then return end
  local cwd = vim.fn.getcwd()
  local rel = buf_path
  -- Strip the cwd prefix if present to make it cwd-relative
  if rel:sub(1, #cwd + 1) == cwd .. '/' then
    rel = rel:sub(#cwd + 2)
  end
  vim.fn.setreg('+', rel)
end, { desc = 'Yank relative path' })
vim.keymap.set('n', '<leader>ya', function() vim.fn.setreg('+', vim.fn.expand('%:p')) end,
  { desc = 'Yank absolute path' })
vim.keymap.set('n', '<leader>yd', function() vim.fn.setreg('+', vim.fn.expand('%:p:h')) end,
  { desc = 'Yank directory path' })

-- Add to # Highlights
vim.keymap.set("v", "<leader>h", "ygg/# Highlights<CR>}O- \"<ESC>pA\"<ESC><C-o><C-o><C-o>",
  { desc = "Add to Highlights" })

-- Visual mode: wrap selection in **...**
vim.keymap.set("x", "<leader>*", 'c**<C-r>"**<Esc>', { silent = true })

-- vim.keymap.set('n', '<leader>yf', function() vim.fn.setreg('+', vim.fn.expand('%:p')) end, { desc = 'Yank absolute path' })

-- MOVE to particular lists (relies on T and R being mapped!)
vim.keymap.set("n", "<leader>mt", "0dd'Tp<C-o>", { desc = "Move to TO DO list." })
vim.keymap.set("n", "<leader>mr", "0dd'Rp<C-o>", { desc = "Move to READING list." })

-- Route change and substitute into the black-hole register by default
vim.keymap.set({ "n", "x" }, "c", '"_c', { noremap = true })
vim.keymap.set({ "n", "x" }, "C", '"_C', { noremap = true })
vim.keymap.set({ "n", "x" }, "S", '"_S', { noremap = true })

vim.keymap.set("n", "<C-k>", "viwb<Esc>i[<Esc>ei<Right>]()<Left>", { desc = "Wrap a word in Markdown link" })

vim.keymap.set("i", "jk", "<Esc>", { desc = "Leave insert mode" })
vim.keymap.set("i", "jj", "<Esc>", { desc = "Leave insert mode" })
vim.keymap.set("n", "ZS", "<Cmd>w<CR>", { desc = "Save file" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Page down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Page up and center" })
vim.keymap.set("n", "o", "A<Enter>", { desc = "Insert line below", remap = true }) -- So dot points continue
vim.keymap.set("n", "<C-CR>", "gx", {
  remap = true,
  silent = true,
  desc = "Open link under cursor",
})

-- Search for [x]
vim.keymap.set("n", "]x", "j0/\\[x\\]<Enter>0", { desc = "Next [x]" })
vim.keymap.set("n", "[x", "0?\\[x\\]<Enter>0", { desc = "Previous [x]" })

vim.keymap.set("n", "<leader>aa", ":.!ai<Enter>", { desc = "AI Answer", remap = true })
vim.keymap.set("x", "<leader>aa", ":.!ai<Enter>'>", { desc = "AI Answer", remap = true })
vim.keymap.set("n", "<leader>as", ":.!aisimp<Enter>", { desc = "AI Simple Answer", remap = true })
vim.keymap.set("x", "<leader>as", ":.!aisimp<Enter>'>", { desc = "AI Simple Answer", remap = true })


-- Auto-completion Snippets
vim.keymap.set("i", "@d", function()
  return os.date("%d/%m/%y")
end, { expr = true, desc = "Insert today's date" })

-- Cycle through available colorschemes quickly
local cycle_colorscheme = (function()
  local state = { list = nil, index = nil }

  local function load_colorschemes()
    if state.list then
      return state.list
    end

    local seen, list = {}, {}
    for _, name in ipairs(vim.fn.getcompletion("", "color")) do
      if not seen[name] then
        seen[name] = true
        list[#list + 1] = name
      end
    end
    table.sort(list)
    state.list = list
    return state.list
  end

  return function(direction)
    direction = direction or 1
    local schemes = load_colorschemes()
    if #schemes == 0 then
      vim.notify("No colorschemes available", vim.log.levels.WARN)
      return
    end

    local current = vim.g.colors_name
    local idx = state.index

    if current then
      if not idx or schemes[idx] ~= current then
        for i, name in ipairs(schemes) do
          if name == current then
            idx = i
            break
          end
        end
      end
    end

    idx = idx or 1
    local start = idx

    for _ = 1, #schemes do
      idx = ((idx - 1 + direction) % #schemes) + 1
      local target = schemes[idx]
      local ok, err = pcall(vim.cmd.colorscheme, target)
      if ok then
        state.index = idx
        vim.notify("Colorscheme: " .. target, vim.log.levels.INFO, { title = "Theme" })
        return
      else
        vim.notify("Failed to load colorscheme " .. target .. ": " .. err, vim.log.levels.WARN)
      end
    end

    vim.notify("Unable to switch colorscheme", vim.log.levels.ERROR)
  end
end)()

vim.keymap.set("n", "<leader>.", function()
  cycle_colorscheme(1)
end, { desc = "Next colorscheme" })

vim.keymap.set("n", "<leader>,", function()
  cycle_colorscheme(-1)
end, { desc = "Previous colorscheme" })

--- <leader>cp to copy the filename of the current file
vim.keymap.set('n', '<leader>cp', function()
  local path = vim.fn.expand('%:p')
  vim.fn.setreg('+', path)
  print('Copied: ' .. path)
end)


-- Move through QuickFix list with alt-j and alt-k
vim.keymap.set("n", "<M-j>", "<cmd>cnext<CR>")
vim.keymap.set("n", "<M-k>", "<cmd>cprev<CR>")


-- Move lines up/down wih alt-shift-j and alt-shift-k
vim.keymap.set("n", "<M-J>", ":m .+1<CR>==", { silent = true })
vim.keymap.set("n", "<M-K>", ":m .-2<CR>==", { silent = true })
vim.keymap.set("v", "<M-J>", ":m '>+1<CR>gv=gv", { silent = true })
vim.keymap.set("v", "<M-K>", ":m '<-2<CR>gv=gv", { silent = true })


-- Use Ctrl-Tab to switch windows (avoids clobbering <C-i>)
vim.keymap.set('n', '<C-Tab>', '<C-w>w', { noremap = true, silent = true })


-- Show Blink completion menu on demand
pcall(function()
  local ok, cmp = pcall(require, 'blink.cmp')
  if ok then
    vim.keymap.set('i', '<C-Space>', function()
      cmp.show()
    end, { desc = 'Show completion' })
  end
end)
