-- Neovim theme setup for lazy.nvim plugin specs
-- Ensures Catppuccin is installed and applied on startup.
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1001,
    config = function()
      require("catppuccin").setup({
        transparent_background = true,
      })

      local function set_bufferline_highlights()
        local ok, palette = pcall(require, "catppuccin.palettes")
        if not ok then
          return
        end

        local flavour = vim.g.catppuccin_flavour or "mocha"
        local colors = palette.get_palette(flavour)
        local magenta = "#821cf2"
        local light_magenta = "#bba1fc"
        local red = "#c70c34"
        local green = "#357e2e"
        local blue = "#215de6"
        local white = "#ffffff"

        local function override_bg(group, bg, attrs)
          local spec = {}
          if attrs then
            for key, value in pairs(attrs) do
              spec[key] = value
            end
          end
          local ok_hl, current = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
          if ok_hl and current then
            for key, value in pairs(current) do
              if spec[key] == nil and key ~= "cterm" and key ~= "ctermbg" and key ~= "ctermfg" then
                spec[key] = value
              end
            end
          end
          spec.bg = bg
          spec.default = nil
          vim.api.nvim_set_hl(0, group, spec)
        end

        override_bg("BufferLineBufferSelected", magenta, { fg = white, italic = false, bold = true })
        vim.api.nvim_set_hl(0, "BufferLineIndicatorSelected", { fg = white, bg = light_magenta })
        vim.api.nvim_set_hl(0, "BufferLineTabSelected", { bg = red, fg = colors.text })
        vim.api.nvim_set_hl(0, "BufferLineSeparatorSelected", { fg = red, bg = green })
        override_bg("BufferLineModifiedSelected", blue, { fg = white })

        local function apply_selected_backgrounds(bg, skip)
          local ok_complete, groups = pcall(vim.fn.getcompletion, "BufferLine", "highlight")
          if not ok_complete or type(groups) ~= "table" then
            return
          end
          for _, name in ipairs(groups) do
            if name:match("Selected$") and not (skip and skip[name]) then
              override_bg(name, bg)
            end
          end
        end

        apply_selected_backgrounds(magenta, {
          BufferLineIndicatorSelected = true,
          BufferLineSeparatorSelected = true,
          BufferLineTabSelected = true,
          BufferLineModifiedSelected = true,
        })

        local function override_icon_highlights(bg)
          local ok_complete, groups = pcall(vim.fn.getcompletion, "BufferLine", "highlight")
          if not ok_complete or type(groups) ~= "table" then
            return
          end
          for _, name in ipairs(groups) do
            if name:match("BufferLine.+Icon.+Selected$") then
              override_bg(name, bg)
            end
          end
        end

        override_icon_highlights(magenta)

        if not vim.g.__bufferline_icon_patch then
          local hl_mod = require("bufferline.highlights")
          local original_set_icon = hl_mod.set_icon_highlight
          hl_mod.set_icon_highlight = function(...)
            local name = original_set_icon(...)
            if name and name:match("Selected$") then
              override_bg(name, magenta)
            end
            return name
          end
          vim.g.__bufferline_icon_patch = true
        end

        local diag_overrides = {
          BufferLineErrorSelected = { fg = colors.red },
          BufferLineErrorDiagnosticSelected = { fg = colors.red },
          BufferLineWarningSelected = { fg = colors.peach },
          BufferLineWarningDiagnosticSelected = { fg = colors.peach },
          BufferLineInfoSelected = { fg = colors.sky },
          BufferLineInfoDiagnosticSelected = { fg = colors.sky },
          BufferLineHintSelected = { fg = colors.teal },
          BufferLineHintDiagnosticSelected = { fg = colors.teal },
          BufferLineDiagnosticSelected = { fg = colors.text },
        }

        for group, attrs in pairs(diag_overrides) do
          override_bg(group, magenta, attrs)
        end
      end

      local function apply_catppuccin()
        vim.cmd.colorscheme("catppuccin")
        set_bufferline_highlights()
      end

      apply_catppuccin()

      local grp = vim.api.nvim_create_augroup("ForceCatppuccin", { clear = true })
      vim.api.nvim_create_autocmd("VimEnter", {
        group = grp,
        callback = function()
          vim.schedule(apply_catppuccin)
        end,
        desc = "Ensure Catppuccin is the final colorscheme on start",
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = grp,
        callback = function(ev)
          if ev.match ~= "catppuccin" then
            vim.schedule(apply_catppuccin)
          end
        end,
        desc = "Force Catppuccin if another colorscheme is applied",
      })
      vim.api.nvim_create_autocmd("User", {
        group = grp,
        pattern = "LazyLoad",
        callback = function(ev)
          if ev.data == "bufferline.nvim" or ev.data == "nvim-web-devicons" then
            vim.schedule(set_bufferline_highlights)
          end
        end,
        desc = "Reapply bufferline highlights after required lazy plugins load",
      })
      vim.api.nvim_create_autocmd("BufAdd", {
        group = grp,
        callback = function()
          vim.schedule(set_bufferline_highlights)
        end,
        desc = "Refresh bufferline highlights when new buffers (and icons) appear",
      })
    end,
  },
}
