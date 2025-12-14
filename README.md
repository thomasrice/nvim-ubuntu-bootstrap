# nvim-ubuntu-bootstrap
Thomas Rice's opinionated Neovim bootstrap for fresh Ubuntu servers.

This vendors my current `~/.config/nvim` (LazyVim-based) and installs the Ubuntu-side dependencies to make it work on a fresh server.

## Install (curl one-liner)

Run as your normal user (it will use `sudo` for apt installs):

```bash
curl -fsSL https://raw.githubusercontent.com/thomasrice/nvim-ubuntu-bootstrap/main/install.sh | bash
```

## What it does

- Installs required packages via `apt` (git, ripgrep, fd, build tools, python, rust/cargo, etc.)
- Installs Node.js (for `mason.nvim` language servers that require it)
- Installs Poetry (for the Python workflow in this config)
- Installs latest Neovim (into `~/.local/opt/nvim` + symlink `~/.local/bin/nvim`)
- Copies config to `~/.config/nvim` (backs up any existing config)
- Runs headless Neovim to sync plugins

## Options

Pass options after `--`:

```bash
curl -fsSL https://raw.githubusercontent.com/thomasrice/nvim-ubuntu-bootstrap/main/install.sh | bash -s -- --no-plugins
```

See `--help` for all flags:

```bash
curl -fsSL https://raw.githubusercontent.com/thomasrice/nvim-ubuntu-bootstrap/main/install.sh | bash -s -- --help
```
