local uv = vim.uv or vim.loop

local manual_nav_state = { context_id = nil, timestamp = nil }

local function now_ms()
  if uv and uv.now then
    return uv.now()
  end
  if vim.loop and vim.loop.now then
    return vim.loop.now()
  end
  return nil
end

local function clear_manual_navigation()
  manual_nav_state.context_id = nil
  manual_nav_state.timestamp = nil
end

local function record_manual_navigation()
  local ok, list = pcall(require, "blink.cmp.completion.list")
  if not ok or not list.context then
    return
  end
  manual_nav_state.context_id = list.context.id
  manual_nav_state.timestamp = now_ms()
end

local function enter_should_accept(existing_list)
  if not manual_nav_state.context_id then
    return false
  end

  local list = existing_list
  if not list then
    local ok, mod = pcall(require, "blink.cmp.completion.list")
    if ok then
      list = mod
    end
  end

  if not list or not list.context or list.context.id ~= manual_nav_state.context_id then
    clear_manual_navigation()
    return false
  end

  local stamp = manual_nav_state.timestamp
  local current = now_ms()
  if stamp and current and (current - stamp) <= 1500 then
    return true
  end
  clear_manual_navigation()
  return false
end

return {
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.keymap = opts.keymap or {}
      opts.keymap.preset = "super-tab"
      opts.keymap["<CR>"] = {
        function(cmp)
          if not cmp.is_visible() then
            clear_manual_navigation()
            return false
          end

          local ok, list_module = pcall(require, "blink.cmp.completion.list")
          local list = ok and list_module or nil
          if list and list.get_selected_item then
            local item = list.get_selected_item()
            if item and item.source_id == "wikilinks" then
              clear_manual_navigation()
              return cmp.select_and_accept()
            end
          end

          if not enter_should_accept(list) then
            return false
          end

          clear_manual_navigation()
          return cmp.accept()
        end,
        "fallback",
      }
      opts.keymap["<C-j>"] = {
        function(cmp)
          local handled = cmp.select_next()
          if handled then
            record_manual_navigation()
          end
          return handled
        end,
        "fallback",
      }
      opts.keymap["<C-k>"] = {
        function(cmp)
          local handled = cmp.select_prev()
          if handled then
            record_manual_navigation()
          end
          return handled
        end,
        "fallback",
      }

      opts.completion = opts.completion or {}
      opts.completion.menu = opts.completion.menu or {}
      opts.completion.menu.auto_show = function(ctx)
        local buf = (ctx and ctx.buf) or 0
        local ft = vim.bo[buf].filetype
        return vim.tbl_contains({ "python", "sh", "lua", "bash", "markdown", "text" }, ft)
      end
      opts.completion.documentation = opts.completion.documentation or {}
      opts.completion.documentation.auto_show = true

      opts.completion.list = opts.completion.list or {}
      opts.completion.list.selection = opts.completion.list.selection or {}
      local selection = opts.completion.list.selection
      local prev_auto_insert = selection.auto_insert
      selection.auto_insert = function(ctx)
        if ctx and ctx.providers and vim.tbl_contains(ctx.providers, "wikilinks") then
          return false
        end
        if type(prev_auto_insert) == "function" then
          return prev_auto_insert(ctx)
        elseif prev_auto_insert ~= nil then
          return prev_auto_insert
        end
        return true
      end

      opts.sources = opts.sources or {}
      local default_sources = opts.sources.default
      if not default_sources then
        default_sources = { "lsp", "path", "snippets", "buffer" }
      end
      if not vim.tbl_contains(default_sources, "project_autocomplete") then
        table.insert(default_sources, "project_autocomplete")
      end
      opts.sources.default = default_sources

      opts.snippets = vim.tbl_deep_extend("force", opts.snippets or {}, {
        preset = "luasnip",
      })

      opts.sources.providers = opts.sources.providers or {}

      opts.sources.providers.snippets = vim.tbl_deep_extend("force",
        opts.sources.providers.snippets or {},
        { opts = { use_label_description = true } }
      )
      if not opts.sources.providers.project_autocomplete then
        opts.sources.providers.project_autocomplete = {
          name = "ProjectAutocomplete",
          module = "util.autocomplete_lists.provider",
          score_offset = 12,
        }
      end

      -- Autocomplete from all open buffers including neo-tree and keep case fixes
      opts.sources.providers.buffer = vim.tbl_deep_extend("force",
        opts.sources.providers.buffer or {},
        {
          opts = {
            get_bufnrs = vim.api.nvim_list_bufs,
          },
          transform_items = function(a, items)
            local keyword = a.get_keyword()
            local correct, apply_case
            if keyword:match("^%l") then
              correct = "^%u%l+$"
              apply_case = string.lower
            elseif keyword:match("^%u") then
              correct = "^%l+$"
              apply_case = string.upper
            else
              return items
            end

            local seen, out = {}, {}
            for _, item in ipairs(items) do
              local raw = item.insertText
              if raw and raw:match("^#") then
                goto continue
              end
              if raw and raw:match(correct) then
                local text = apply_case(raw:sub(1, 1)) .. raw:sub(2)
                item.insertText = text
                item.label = text
              end
              local key = item.insertText or raw
              if key and not seen[key] then
                seen[key] = true
                table.insert(out, item)
              end
              ::continue::
            end
            return out
          end,
        }
      )

      if not opts.sources.providers.wikilinks then
        opts.sources.providers.wikilinks = {
          name = "WikiLinks",
          module = "wikilinks.completion_source",
          score_offset = 8,
          min_keyword_length = 0,
          enabled = function()
            local ft = vim.bo.filetype
            return ft == "markdown" or ft == "markdown.mdx" or ft == "markdown.pandoc"
          end,
        }
      end

      opts.sources.per_filetype = opts.sources.per_filetype or {}

      local function ensure_markdown_sources(ft)
        local sources = opts.sources.per_filetype[ft]
        if not sources then
          sources = { inherit_defaults = true }
        elseif type(sources) == "function" then
          return
        elseif sources.inherit_defaults == nil then
          sources.inherit_defaults = true
        end

        local already_present = false
        if type(sources) == "table" then
          for _, id in ipairs(sources) do
            if id == "wikilinks" then
              already_present = true
              break
            end
          end
        end

        if not already_present then
          table.insert(sources, 1, "wikilinks")
        end

        opts.sources.per_filetype[ft] = sources
      end

      ensure_markdown_sources("markdown")
      ensure_markdown_sources("markdown.mdx")
      ensure_markdown_sources("markdown.pandoc")
    end,
  },
}
