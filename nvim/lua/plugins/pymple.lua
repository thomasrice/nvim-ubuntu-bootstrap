return {
  {
    "alexpasmantier/pymple.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      -- optional (nicer ui)
      "stevearc/dressing.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    build = function()
      if vim.fn.executable("gg") == 1 then
        return
      end
      if vim.fn.executable("cargo") == 0 then
        vim.schedule(function()
          vim.notify(
            "pymple.nvim: cargo is not available; install grip-grab manually.",
            vim.log.levels.WARN
          )
        end)
        return
      end
      local output = vim.fn.system({ "cargo", "install", "grip-grab" })
      if vim.v.shell_error ~= 0 then
        vim.schedule(function()
          vim.notify(
            ("pymple.nvim: failed to install grip-grab automatically.\n%s"):format(
              output
            ),
            vim.log.levels.ERROR
          )
        end)
      end
    end,
    config = function()
      require("pymple").setup()

      local neo_attached = false
      local function attach_to_neo_tree()
        if neo_attached then
          return true
        end

        local ok_events, events = pcall(require, "neo-tree.events")
        if not ok_events then
          return false
        end

        local ok_api, api = pcall(require, "pymple.api")
        if not ok_api then
          return false
        end
        local ok_config, config = pcall(require, "pymple.config")
        if not ok_config or not config.user_config then
          return false
        end

        local function on_move(args)
          api.update_imports(
            args.source,
            args.destination,
            config.user_config.update_imports
          )
        end

        events.subscribe({
          id = "pymple_file_moved",
          event = events.FILE_MOVED,
          handler = on_move,
        })
        events.subscribe({
          id = "pymple_file_renamed",
          event = events.FILE_RENAMED,
          handler = on_move,
        })
        neo_attached = true
        return true
      end

      local snacks_attached = false
      local function attach_to_snacks()
        if snacks_attached then
          return true
        end

        local ok_snacks, snacks = pcall(require, "snacks")
        if not ok_snacks then
          return false
        end
        local rename = snacks.rename
        if not rename or type(rename.rename_file) ~= "function" then
          return false
        end
        if rename._pymple_wrapped then
          snacks_attached = true
          return true
        end

        local original = rename.rename_file
        rename.rename_file = function(opts)
          opts = opts or {}
          local user_on_rename = opts.on_rename
          opts.on_rename = function(new_path, old_path, ok)
            if user_on_rename then
              user_on_rename(new_path, old_path, ok)
            end
            if ok then
              local ok_api, api = pcall(require, "pymple.api")
              if not ok_api then
                return
              end
              local ok_config, config = pcall(require, "pymple.config")
              if not ok_config or not config.user_config then
                return
              end
              api.update_imports(
                old_path,
                new_path,
                config.user_config.update_imports
              )
            end
          end
          return original(opts)
        end
        rename._pymple_wrapped = true
        snacks_attached = true
        return true
      end

      if not attach_to_neo_tree() then
        vim.api.nvim_create_autocmd("User", {
          pattern = "LazyLoad",
          callback = function(event)
            if event.data == "neo-tree.nvim" then
              attach_to_neo_tree()
            end
          end,
          desc = "Attach pymple.nvim to neo-tree rename events",
        })
      end

      if not attach_to_snacks() then
        vim.api.nvim_create_autocmd("User", {
          pattern = "LazyLoad",
          callback = function(event)
            if event.data == "snacks.nvim" then
              attach_to_snacks()
            end
          end,
          desc = "Attach pymple.nvim to snacks rename events",
        })
      end
    end,
  },
}
