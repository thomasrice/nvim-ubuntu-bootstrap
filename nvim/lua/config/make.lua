local trim = vim.trim or function(str)
  return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local python_errorformat = {
  [[%-GTraceback%.%#]], -- ignore the "Traceback ..." header
  [[%E  File "%f"\, line %l\, in %m]], -- capture each stack frame
  [[%-G    %.%#]], -- drop indented code lines
  [[%-G        %.%#]], -- drop pointer indicator lines
}

local python_make_active = false

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.makeprg = "poetry run python %:p"
    vim.opt_local.errorformat = vim.deepcopy(python_errorformat)
  end,
})

vim.api.nvim_create_autocmd("QuickFixCmdPre", {
  pattern = "make",
  callback = function()
    python_make_active = vim.bo.filetype == "python"
  end,
})

vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  pattern = "make",
  callback = function()
    if not python_make_active then
      return
    end
    python_make_active = false

    local qf = vim.fn.getqflist({ id = 0, items = 1, title = 1 })
    local items = qf.items or {}
    if #items == 0 then
      return
    end

    local summary
    local filtered = {}
    for _, item in ipairs(items) do
      if item.valid == 1 and item.bufnr ~= 0 then
        filtered[#filtered + 1] = item
      else
        local text = trim(item.text or "")
        if text ~= "" and not text:lower():match("^traceback") then
          summary = text
        end
      end
    end

    if #filtered == 0 then
      return
    end

    if summary then
      for _, item in ipairs(filtered) do
        if item.text and item.text ~= "" then
          item.text = string.format("%s — %s", item.text, summary)
        else
          item.text = summary
        end
      end
    end

    vim.fn.setqflist({}, "r", { id = qf.id, items = filtered, title = qf.title })
  end,
})
