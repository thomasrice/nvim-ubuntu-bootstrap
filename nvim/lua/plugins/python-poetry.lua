local uv = vim.uv or vim.loop

local function path_stat(path)
  if not path or path == "" then
    return nil
  end
  return uv.fs_stat(path)
end

local function file_exists(path)
  local stat = path_stat(path)
  return stat and stat.type == "file"
end

local function resolve_python_bin(env_path)
  if vim.fn.has("win32") == 1 then
    return env_path .. "\\Scripts\\python.exe"
  end
  return env_path .. "/bin/python"
end

local function python_paths_for(env_path)
  if not path_stat(env_path) then
    return nil
  end
  local python_bin = resolve_python_bin(env_path)
  if not file_exists(python_bin) then
    return nil
  end
  local parent = vim.fs.dirname(env_path)
  local name = vim.fs.basename(env_path)
  return {
    env_path = env_path,
    python_bin = python_bin,
    venv_path = parent,
    venv_name = name,
  }
end

local function run_poetry_env_info(root_dir)
  if vim.fn.executable("poetry") == 0 then
    return nil
  end
  local manifest_exists = path_stat(root_dir .. "/pyproject.toml") or path_stat(root_dir .. "/poetry.lock")
  if not manifest_exists then
    return nil
  end

  if vim.system then
    local result = vim.system({ "poetry", "env", "info", "-p" }, { cwd = root_dir, text = true }):wait()
    if not result or result.code ~= 0 then
      return nil
    end
    local stdout = vim.trim(result.stdout or "")
    return stdout ~= "" and stdout or nil
  end

  local cmd = string.format("cd %s && poetry env info -p", vim.fn.shellescape(root_dir))
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local trimmed = vim.trim(output)
  return trimmed ~= "" and trimmed or nil
end

local function detect_poetry_environment(root_dir)
  if not root_dir or root_dir == "" then
    return nil
  end
  return run_poetry_env_info(root_dir)
end

local function fetch_python_environment(root_dir)
  local env_path = detect_poetry_environment(root_dir)
  local details = env_path and python_paths_for(env_path)
  if details then
    return details
  end

  local fallback_env = root_dir and (root_dir .. "/.venv") or nil
  return fallback_env and python_paths_for(fallback_env) or nil
end

local function apply_python_environment(config, root_dir)
  local details = fetch_python_environment(root_dir)
  if not details then
    return
  end

  config.settings = config.settings or {}
  config.settings.python = config.settings.python or {}
  config.settings.python.pythonPath = details.python_bin
  config.settings.python.venvPath = details.venv_path
  config.settings.python.venv = details.venv_name

  config.cmd_env = config.cmd_env or {}
  config.cmd_env.VIRTUAL_ENV = details.env_path
  if vim.fn.has("win32") == 0 then
    local bin_dir = details.env_path .. "/bin"
    config.cmd_env.PATH = bin_dir .. ":" .. (config.cmd_env.PATH or vim.env.PATH or "")
  else
    local scripts_dir = details.env_path .. "\\Scripts"
    config.cmd_env.PATH = scripts_dir .. ";" .. (config.cmd_env.PATH or vim.env.PATH or "")
  end
end

local function configure_pyright(config, root_dir)
  local resolved_root = root_dir or config.root_dir
  if not resolved_root and config.workspace_folders and config.workspace_folders[1] then
    resolved_root = config.workspace_folders[1].name
  end
  if type(resolved_root) == "table" then
    resolved_root = resolved_root[1]
  end
  if not resolved_root or resolved_root == "" then
    return
  end
  config.settings = config.settings or {}
  config.settings.python = config.settings.python or {}
  config.settings.python.analysis = config.settings.python.analysis or {}
  local analysis = config.settings.python.analysis
  local overrides = analysis.diagnosticSeverityOverrides or {}
  overrides.reportWildcardImportFromLibrary = "none"
  overrides.reportUndefinedVariable = "none"
  overrides.reportUnknownMemberType = "none"
  overrides.reportRedeclaration = "none"
  analysis.diagnosticSeverityOverrides = overrides

  local stub_path = resolved_root .. "/typings"
  if path_stat(stub_path) then
    analysis.stubPath = stub_path
  end
  apply_python_environment(config, resolved_root)
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      local pyright_opts = opts.servers.pyright or {}

      local original_before_init = pyright_opts.before_init
      pyright_opts.before_init = function(params, config)
        configure_pyright(config, config.root_dir)
        if original_before_init then
          original_before_init(params, config)
        end
      end

      local original_on_new_config = pyright_opts.on_new_config
      pyright_opts.on_new_config = function(config, root_dir)
        configure_pyright(config, root_dir)
        if original_on_new_config then
          original_on_new_config(config, root_dir)
        end
      end

      opts.servers.pyright = pyright_opts
    end,
  },
}
