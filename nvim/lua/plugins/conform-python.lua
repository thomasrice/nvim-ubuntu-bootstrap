return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters = opts.formatters or {}
      local python_chain = {}
      local seen = {}
      for _, name in ipairs({ "isort", "black" }) do
        python_chain[#python_chain + 1] = name
        seen[name] = true
      end
      for _, existing in ipairs(opts.formatters_by_ft.python or {}) do
        if not seen[existing] then
          python_chain[#python_chain + 1] = existing
        end
      end
      opts.formatters_by_ft.python = python_chain

      opts.formatters.isort = vim.tbl_deep_extend("force", opts.formatters.isort or {}, {
        command = "poetry",
        prepend_args = {
          "run",
          "isort",
          "--profile",
          "black",
          "--atomic",
          "--filter-files",
        },
      })

      opts.formatters.black = vim.tbl_deep_extend("force", opts.formatters.black or {}, {
        command = "poetry",
        prepend_args = {
          "run",
          "black",
        },
      })
    end,
  },
}
