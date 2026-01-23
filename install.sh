#!/usr/bin/env bash
set -euo pipefail
umask 022

REPO_DEFAULT="thomasrice/nvim-ubuntu-bootstrap"
REF_DEFAULT="main"

log() {
  printf '%s %s\n' "nvim-ubuntu-bootstrap:" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Installs Neovim and dependencies locally to ~/.local (no sudo required).

Options:
  --no-node        Skip Node.js install (mason needs Node for some tools)
  --no-poetry      Skip poetry install
  --no-nvim        Skip Neovim install/upgrade
  --no-config      Skip copying the nvim config
  --no-plugins     Skip running headless Neovim to install plugins
  --no-tools       Skip installing ripgrep, fd, fzf
  -h, --help       Show this help

Prerequisites (must be installed already):
  curl, tar, git, python3

Environment:
  NVIM_BOOTSTRAP_REPO   GitHub repo "owner/name" (default: thomasrice/nvim-ubuntu-bootstrap)
  NVIM_BOOTSTRAP_REF    Git ref to fetch (default: main)
EOF
}

INSTALL_NODE=1
INSTALL_POETRY=1
INSTALL_NVIM=1
INSTALL_CONFIG=1
INSTALL_TOOLS=1
RUN_PLUGIN_SYNC=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-node) INSTALL_NODE=0 ;;
    --no-poetry) INSTALL_POETRY=0 ;;
    --no-nvim) INSTALL_NVIM=0 ;;
    --no-config) INSTALL_CONFIG=0 ;;
    --no-plugins) RUN_PLUGIN_SYNC=0 ;;
    --no-tools) INSTALL_TOOLS=0 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (try --help)"
      ;;
  esac
  shift
done

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    log "Warning: intended for Ubuntu (detected: ${ID:-unknown})."
  fi
else
  log "Warning: unable to detect OS (missing /etc/os-release)."
fi

TARGET_USER="$(id -un)"
TARGET_HOME="$HOME"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

check_prerequisites() {
  log "Checking prerequisites..."
  local missing=()
  for cmd in curl tar git python3; do
    if ! has_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing prerequisites: ${missing[*]}. Please install them first."
  fi
}

get_arch() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64) echo "x86_64" ;;
    aarch64 | arm64) echo "aarch64" ;;
    *) die "Unsupported architecture: $arch" ;;
  esac
}

ensure_local_bin() {
  mkdir -p "$TARGET_HOME/.local/bin"
  if [[ ":$PATH:" != *":$TARGET_HOME/.local/bin:"* ]]; then
    export PATH="$TARGET_HOME/.local/bin:$PATH"
  fi
}

install_ripgrep() {
  [[ "$INSTALL_TOOLS" -eq 1 ]] || return 0
  if has_cmd rg; then return 0; fi

  log "Installing ripgrep..."
  local arch
  arch="$(get_arch)"
  local version="14.1.1"
  local asset="ripgrep-${version}-${arch}-unknown-linux-musl.tar.gz"
  local url="https://github.com/BurntSushi/ripgrep/releases/download/${version}/${asset}"

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")

  curl -fsSL "$url" -o "$tmp/rg.tar.gz"
  tar -xzf "$tmp/rg.tar.gz" -C "$tmp"
  cp "$tmp/ripgrep-${version}-${arch}-unknown-linux-musl/rg" "$TARGET_HOME/.local/bin/rg"
  chmod +x "$TARGET_HOME/.local/bin/rg"
}

install_fd() {
  [[ "$INSTALL_TOOLS" -eq 1 ]] || return 0
  if has_cmd fd; then return 0; fi

  log "Installing fd..."
  local arch
  arch="$(get_arch)"
  local version="10.2.0"
  local asset="fd-v${version}-${arch}-unknown-linux-musl.tar.gz"
  local url="https://github.com/sharkdp/fd/releases/download/v${version}/${asset}"

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")

  curl -fsSL "$url" -o "$tmp/fd.tar.gz"
  tar -xzf "$tmp/fd.tar.gz" -C "$tmp"
  cp "$tmp/fd-v${version}-${arch}-unknown-linux-musl/fd" "$TARGET_HOME/.local/bin/fd"
  chmod +x "$TARGET_HOME/.local/bin/fd"
}

install_fzf() {
  [[ "$INSTALL_TOOLS" -eq 1 ]] || return 0
  if has_cmd fzf; then return 0; fi

  log "Installing fzf..."
  local arch
  arch="$(get_arch)"
  local version="0.56.3"
  local arch_name
  case "$arch" in
    x86_64) arch_name="amd64" ;;
    aarch64) arch_name="arm64" ;;
  esac
  local asset="fzf-${version}-linux_${arch_name}.tar.gz"
  local url="https://github.com/junegunn/fzf/releases/download/v${version}/${asset}"

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")

  curl -fsSL "$url" -o "$tmp/fzf.tar.gz"
  tar -xzf "$tmp/fzf.tar.gz" -C "$tmp"
  cp "$tmp/fzf" "$TARGET_HOME/.local/bin/fzf"
  chmod +x "$TARGET_HOME/.local/bin/fzf"
}

ensure_node() {
  [[ "$INSTALL_NODE" -eq 1 ]] || return 0

  # Check if node >= 18 already exists
  if has_cmd node; then
    local major
    major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
    if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 18 ]]; then
      return 0
    fi
  fi

  log "Installing Node.js via fnm..."
  local arch
  arch="$(get_arch)"
  local arch_name
  case "$arch" in
    x86_64) arch_name="linux" ;;
    aarch64) arch_name="linux-arm64" ;;
  esac

  # Install fnm if not present
  if ! has_cmd fnm; then
    local fnm_url="https://fnm.vercel.app/install"
    curl -fsSL "$fnm_url" | bash -s -- --install-dir "$TARGET_HOME/.local/bin" --skip-shell
  fi

  # Set up fnm environment
  export FNM_DIR="$TARGET_HOME/.local/share/fnm"
  eval "$("$TARGET_HOME/.local/bin/fnm" env)"

  # Install Node.js 20
  "$TARGET_HOME/.local/bin/fnm" install 20
  "$TARGET_HOME/.local/bin/fnm" default 20

  # Create symlinks in .local/bin for node/npm
  local node_path
  node_path="$("$TARGET_HOME/.local/bin/fnm" exec --using=20 which node)"
  local npm_path
  npm_path="$("$TARGET_HOME/.local/bin/fnm" exec --using=20 which npm)"
  ln -sf "$node_path" "$TARGET_HOME/.local/bin/node"
  ln -sf "$npm_path" "$TARGET_HOME/.local/bin/npm"
}

ensure_poetry() {
  [[ "$INSTALL_POETRY" -eq 1 ]] || return 0

  if has_cmd poetry; then
    return 0
  fi

  if has_cmd pipx; then
    log "Installing poetry via pipx..."
    pipx install poetry
    return 0
  fi

  log "Installing poetry via official installer..."
  need_cmd curl
  need_cmd python3

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  curl -fsSL https://install.python-poetry.org -o "$tmp/install-poetry.py"
  python3 "$tmp/install-poetry.py" -y
}

install_neovim() {
  [[ "$INSTALL_NVIM" -eq 1 ]] || return 0

  if has_cmd nvim; then
    local current_line major minor
    current_line="$(nvim --version | head -n1 || true)"
    if [[ "$current_line" =~ ^NVIM\ v([0-9]+)\.([0-9]+) ]]; then
      major="${BASH_REMATCH[1]}"
      minor="${BASH_REMATCH[2]}"
      if [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]]; then
        if (( major > 0 || minor >= 10 )); then
          return 0
        fi
      fi
    fi
  fi

  need_cmd curl
  need_cmd tar

  local arch
  arch="$(uname -m)"
  local asset=""
  case "$arch" in
    x86_64) asset="nvim-linux-x86_64.tar.gz" ;;
    aarch64 | arm64) asset="nvim-linux-arm64.tar.gz" ;;
    *)
      die "Unsupported architecture for Neovim prebuild: $arch"
      ;;
  esac

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  local url="https://github.com/neovim/neovim/releases/latest/download/$asset"
  log "Installing Neovim from $url..."
  curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  local extracted
  extracted="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d -name 'nvim-linux-*' | head -n1 || true)"
  [[ -n "$extracted" && -d "$extracted" ]] || die "Failed to unpack Neovim archive."

  local prefix="$TARGET_HOME/.local/opt/nvim"
  mkdir -p "$TARGET_HOME/.local/opt" "$TARGET_HOME/.local/bin"
  rm -rf "$prefix"
  mv "$extracted" "$prefix"
  ln -sf "$prefix/bin/nvim" "$TARGET_HOME/.local/bin/nvim"
}

resolve_bootstrap_root() {
  local repo="${NVIM_BOOTSTRAP_REPO:-$REPO_DEFAULT}"
  local ref="${NVIM_BOOTSTRAP_REF:-$REF_DEFAULT}"

  local script_path="${BASH_SOURCE[0]}"
  if [[ -f "$script_path" ]]; then
    local script_dir
    script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
    if [[ -d "$script_dir/nvim" ]]; then
      printf '%s\n' "$script_dir"
      return 0
    fi
  fi

  need_cmd curl
  need_cmd tar

  local tmp
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")

  local url="https://github.com/${repo}/archive/refs/heads/${ref}.tar.gz"
  log "Fetching config from $repo@$ref..."
  curl -fsSL "$url" -o "$tmp/repo.tar.gz"
  tar -xzf "$tmp/repo.tar.gz" -C "$tmp"

  local extracted
  extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  [[ -n "$extracted" && -d "$extracted/nvim" ]] || die "Downloaded repo does not contain ./nvim"

  printf '%s\n' "$extracted"
}

install_config() {
  [[ "$INSTALL_CONFIG" -eq 1 ]] || return 0

  local bootstrap_root="$1"
  local src="$bootstrap_root/nvim"
  local dest="$TARGET_HOME/.config/nvim"

  [[ -d "$src" ]] || die "Config source missing: $src"

  mkdir -p "$TARGET_HOME/.config"

  if [[ -e "$dest" ]]; then
    local backup="${dest}.backup-$(date +%Y%m%d%H%M%S)"
    log "Backing up existing nvim config to $backup"
    mv "$dest" "$backup"
  fi

  log "Installing Neovim config to $dest"
  cp -a "$src" "$dest"
}

sync_plugins() {
  [[ "$RUN_PLUGIN_SYNC" -eq 1 ]] || return 0

  local nvim_bin="$TARGET_HOME/.local/bin/nvim"
  if [[ ! -x "$nvim_bin" ]]; then
    if has_cmd nvim; then nvim_bin="nvim"; else
      log "Warning: nvim not found; skipping plugin sync."
      return 0
    fi
  fi

  log "Installing/updating plugins (headless)..."
  "$nvim_bin" --headless "+Lazy! sync" "+qa"

  log "Waiting for Mason installs to finish (headless)..."
  local tmp lua_file
  tmp="$(mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  lua_file="$tmp/wait_mason.lua"

  cat >"$lua_file" <<'LUA'
local ok, registry = pcall(require, "mason-registry")
if not ok then
  vim.cmd("qa")
  return
end

local function any_installing()
  registry.refresh()
  for _, pkg in ipairs(registry.get_installed_packages()) do
    if pkg:is_installing() then return true end
  end
  return false
end

local timeout = 300
local start = vim.loop.now()

local function elapsed()
  return (vim.loop.now() - start) / 1000
end

local function tick()
  if not any_installing() then
    vim.cmd("qa")
    return
  end
  if elapsed() > timeout then
    vim.notify("Timeout waiting for Mason installs", vim.log.levels.WARN)
    vim.cmd("qa")
    return
  end
  vim.defer_fn(tick, 500)
end

tick()
LUA

  "$nvim_bin" --headless -c "luafile $lua_file"
}

ensure_rustup() {
  # If cargo already exists (apt, homebrew, etc.), use it
  if has_cmd cargo; then
    return 0
  fi

  log "Installing Rust toolchain via rustup..."
  need_cmd curl
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path

  # Symlink cargo/rustc to .local/bin
  mkdir -p "$TARGET_HOME/.local/bin"
  ln -sf "$TARGET_HOME/.cargo/bin/cargo" "$TARGET_HOME/.local/bin/cargo"
  ln -sf "$TARGET_HOME/.cargo/bin/rustc" "$TARGET_HOME/.local/bin/rustc"
  ln -sf "$TARGET_HOME/.cargo/bin/rustup" "$TARGET_HOME/.local/bin/rustup"

  # Ensure stable is installed
  "$TARGET_HOME/.cargo/bin/rustup" default stable
}

ensure_grip_grab() {
  if has_cmd gg; then return 0; fi
  if ! has_cmd cargo; then
    log "Warning: cargo not found; cannot install grip-grab/gg."
    return 0
  fi
  log "Installing grip-grab (gg) via cargo..."
  cargo install grip-grab

  # Symlink to .local/bin if installed via rustup
  if [[ -x "$TARGET_HOME/.cargo/bin/gg" ]]; then
    ln -sf "$TARGET_HOME/.cargo/bin/gg" "$TARGET_HOME/.local/bin/gg"
  fi
}

CLEANUP_DIRS=()
cleanup() {
  for dir in "${CLEANUP_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

# Main installation sequence
check_prerequisites
ensure_local_bin

install_ripgrep
install_fd
install_fzf
ensure_node
ensure_poetry
install_neovim

BOOTSTRAP_ROOT="$(resolve_bootstrap_root)"
install_config "$BOOTSTRAP_ROOT"
ensure_rustup
ensure_grip_grab
sync_plugins

log "Done."
log ""
log "Make sure ~/.local/bin is in your PATH. Add this to your ~/.bashrc or ~/.zshrc:"
log '  export PATH="$HOME/.local/bin:$PATH"'
