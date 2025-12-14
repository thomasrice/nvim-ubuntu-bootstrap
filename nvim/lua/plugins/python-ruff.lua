local function ensure_ignore_args(args)
  args = args or {}
  local ignore_index
  for idx, value in ipairs(args) do
    if value == "--ignore" or value == "--extend-ignore" then
      ignore_index = idx + 1
      break
    end
  end

  local target_codes = { F403 = true, F405 = true }

  if ignore_index and args[ignore_index] then
    local existing = {}
    local codes = vim.split(args[ignore_index], ",", { trimempty = true })
    for _, code in ipairs(codes) do
      existing[code] = true
    end
    for code in pairs(target_codes) do
      if not existing[code] then
        table.insert(codes, code)
      end
    end
    args[ignore_index] = table.concat(codes, ",")
  else
    local additions = {}
    for code in pairs(target_codes) do
      table.insert(additions, code)
    end
    table.sort(additions)
    vim.list_extend(args, { "--extend-ignore", table.concat(additions, ",") })
  end

  return args
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      local ruff = opts.servers.ruff or {}
      ruff.init_options = ruff.init_options or {}
      ruff.init_options.settings = ruff.init_options.settings or {}
      ruff.init_options.settings.args = ensure_ignore_args(ruff.init_options.settings.args)
      ruff.settings = ruff.settings or {}
      ruff.settings.args = ensure_ignore_args(ruff.settings.args)
      opts.servers.ruff = ruff

      local ruff_lsp = opts.servers.ruff_lsp or {}
      ruff_lsp.init_options = ruff_lsp.init_options or {}
      ruff_lsp.init_options.settings = ruff_lsp.init_options.settings or {}
      ruff_lsp.init_options.settings.args = ensure_ignore_args(ruff_lsp.init_options.settings.args)
      ruff_lsp.settings = ruff_lsp.settings or {}
      ruff_lsp.settings.args = ensure_ignore_args(ruff_lsp.settings.args)
      opts.servers.ruff_lsp = ruff_lsp
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      local extra_args = ensure_ignore_args({})
      local args = {
        "check",
        "--force-exclude",
        "--quiet",
      }
      vim.list_extend(args, extra_args)
      vim.list_extend(args, {
        "--stdin-filename",
        function()
          return vim.api.nvim_buf_get_name(0)
        end,
        "--no-fix",
        "--output-format",
        "json",
        "-",
      })

      opts.linters.ruff = opts.linters.ruff or {}
      opts.linters.ruff.args = args
    end,
  },
}
