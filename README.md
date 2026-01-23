# nvim-ubuntu-bootstrap
Thomas Rice's opinionated Neovim bootstrap for fresh Ubuntu servers.

This vendors my current `~/.config/nvim` (LazyVim-based) and installs the dependencies to make it work on a fresh server. **No sudo required** - everything installs to `~/.local`.

## Prerequisites

You need these installed already (most Ubuntu systems have them):

```bash
curl tar git python3
```

## Install (curl one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/thomasrice/nvim-ubuntu-bootstrap/main/install.sh | bash
```

After installation, ensure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## What it does

- Downloads and installs ripgrep, fd, fzf (static binaries to `~/.local/bin`)
- Installs Node.js via fnm (for `mason.nvim` language servers)
- Installs Poetry (for Python workflow)
- Installs Rust via rustup (for grip-grab and other tools)
- Installs latest Neovim (to `~/.local/opt/nvim` + symlink)
- Copies config to `~/.config/nvim` (backs up any existing config)
- Runs headless Neovim to sync plugins

## Options

Pass options after `--`:

```bash
curl -fsSL https://raw.githubusercontent.com/thomasrice/nvim-ubuntu-bootstrap/main/install.sh | bash -s -- --no-plugins
```

Available flags:

| Flag | Description |
|------|-------------|
| `--no-node` | Skip Node.js install |
| `--no-poetry` | Skip Poetry install |
| `--no-nvim` | Skip Neovim install |
| `--no-config` | Skip config copy |
| `--no-plugins` | Skip plugin sync |
| `--no-tools` | Skip ripgrep, fd, fzf |
| `-h, --help` | Show help |
