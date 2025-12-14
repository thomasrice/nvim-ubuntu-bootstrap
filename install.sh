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

Options:
  --no-packages    Skip apt package installs
  --no-node        Skip Node.js install/upgrade (mason needs Node for some tools)
  --no-poetry      Skip poetry install (pipx)
  --no-nvim        Skip Neovim install/upgrade
  --no-config      Skip copying the nvim config
  --no-plugins     Skip running headless Neovim to install plugins
  -h, --help       Show this help

Environment:
  NVIM_BOOTSTRAP_REPO   GitHub repo "owner/name" (default: thomasrice/nvim-ubuntu-bootstrap)
  NVIM_BOOTSTRAP_REF    Git ref to fetch (default: main)
EOF
}

INSTALL_PACKAGES=1
INSTALL_NODE=1
INSTALL_POETRY=1
INSTALL_NVIM=1
INSTALL_CONFIG=1
RUN_PLUGIN_SYNC=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-packages) INSTALL_PACKAGES=0 ;;
    --no-node) INSTALL_NODE=0 ;;
    --no-poetry) INSTALL_POETRY=0 ;;
    --no-nvim) INSTALL_NVIM=0 ;;
    --no-config) INSTALL_CONFIG=0 ;;
    --no-plugins) RUN_PLUGIN_SYNC=0 ;;
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

SUDO=()

ensure_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi
  if [[ "${#SUDO[@]}" -eq 0 ]]; then
    command -v sudo >/dev/null 2>&1 || die "sudo is required to install system packages."
    # Verify we can sudo without prompting
    if ! sudo -n true 2>/dev/null; then
      die "This script needs passwordless sudo (sudo -n). Configure NOPASSWD for this user or run as root."
    fi
    SUDO=(sudo -n)
  fi
}

TARGET_USER="$(id -un)"
if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
  TARGET_USER="$SUDO_USER"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
if [[ -z "${TARGET_HOME:-}" ]]; then
  TARGET_HOME="$HOME"
fi

run_as_target() {
  if [[ "$(id -u)" -eq 0 && "$TARGET_USER" != "root" ]]; then
    sudo -u "$TARGET_USER" -H "$@"
  else
    "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

target_has_cmd() {
  local cmd="$1"
  if [[ "$(id -u)" -eq 0 && "$TARGET_USER" != "root" ]]; then
    local quoted
    quoted="$(printf '%q' "$cmd")"
    sudo -u "$TARGET_USER" -H bash -lc "command -v $quoted >/dev/null 2>&1"
  else
    command -v "$cmd" >/dev/null 2>&1
  fi
}

ensure_base_packages() {
  [[ "$INSTALL_PACKAGES" -eq 1 ]] || return 0

  ensure_sudo
  log "Installing Ubuntu packages (apt)…"
  "${SUDO[@]}" apt-get update
  DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    gzip \
    tar \
    unzip \
    ripgrep \
    fd-find \
    fzf \
    build-essential \
    python3 \
    python3-venv \
    python3-pip \
    cargo \
    rustc

  local optional_pkgs=(
    pipx
    python3-pynvim
  )
  for pkg in "${optional_pkgs[@]}"; do
    if ! DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y --no-install-recommends "$pkg"; then
      log "Warning: unable to install optional package '$pkg' via apt."
    fi
  done
}

ensure_fd() {
  if target_has_cmd fd; then
    return 0
  fi
  if command -v fdfind >/dev/null 2>&1; then
    run_as_target mkdir -p "$TARGET_HOME/.local/bin"
    run_as_target ln -sf "$(command -v fdfind)" "$TARGET_HOME/.local/bin/fd"
    return 0
  fi
  log "Warning: fd not found (install fd-find or provide fd)."
}

ensure_node() {
  [[ "$INSTALL_NODE" -eq 1 ]] || return 0

  local major=""
  if command -v node >/dev/null 2>&1; then
    major="$(node -v | sed -E 's/^v([0-9]+).*/\\1/')"
    if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -ge 18 ]]; then
      return 0
    fi
  fi

  ensure_sudo

  log "Installing Node.js (via NodeSource)…"
  DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg
  need_cmd curl
  curl -fsSL https://deb.nodesource.com/setup_20.x | "${SUDO[@]}" -E bash -
  DEBIAN_FRONTEND=noninteractive "${SUDO[@]}" apt-get install -y --no-install-recommends nodejs
}

ensure_poetry() {
  [[ "$INSTALL_POETRY" -eq 1 ]] || return 0

  if target_has_cmd poetry; then
    return 0
  fi

  if command -v pipx >/dev/null 2>&1; then
    log "Installing poetry (pipx)…"
    run_as_target pipx install poetry
    return 0
  fi

  log "Installing poetry (official installer)…"
  need_cmd curl
  need_cmd python3

  local tmp
  tmp="$(run_as_target mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  run_as_target curl -fsSL https://install.python-poetry.org -o "$tmp/install-poetry.py"
  run_as_target python3 "$tmp/install-poetry.py" -y
}

install_neovim() {
  [[ "$INSTALL_NVIM" -eq 1 ]] || return 0

  if target_has_cmd nvim; then
    local current_line major minor
    current_line="$(run_as_target nvim --version | head -n1 || true)"
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
  tmp="$(run_as_target mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  local url="https://github.com/neovim/neovim/releases/latest/download/$asset"
  log "Installing Neovim from $url…"
  run_as_target curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  run_as_target tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  local extracted
  extracted="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d -name 'nvim-linux-*' | head -n1 || true)"
  [[ -n "$extracted" && -d "$extracted" ]] || die "Failed to unpack Neovim archive."

  local prefix="$TARGET_HOME/.local/opt/nvim"
  run_as_target mkdir -p "$TARGET_HOME/.local/opt" "$TARGET_HOME/.local/bin"
  run_as_target rm -rf "$prefix"
  run_as_target mv "$extracted" "$prefix"
  run_as_target ln -sf "$prefix/bin/nvim" "$TARGET_HOME/.local/bin/nvim"
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
  tmp="$(run_as_target mktemp -d)"
  CLEANUP_DIRS+=("$tmp")

  local url="https://github.com/${repo}/archive/refs/heads/${ref}.tar.gz"
  log "Fetching config from $repo@$ref…"
  run_as_target curl -fsSL "$url" -o "$tmp/repo.tar.gz"
  run_as_target tar -xzf "$tmp/repo.tar.gz" -C "$tmp"

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

  run_as_target mkdir -p "$TARGET_HOME/.config"

  if [[ -e "$dest" ]]; then
    local backup="${dest}.backup-$(date +%Y%m%d%H%M%S)"
    log "Backing up existing nvim config to $backup"
    run_as_target mv "$dest" "$backup"
  fi

  log "Installing Neovim config to $dest"
  run_as_target cp -a "$src" "$dest"
}

sync_plugins() {
  [[ "$RUN_PLUGIN_SYNC" -eq 1 ]] || return 0

  local nvim_bin="$TARGET_HOME/.local/bin/nvim"
  if [[ ! -x "$nvim_bin" ]]; then
    if target_has_cmd nvim; then nvim_bin="nvim"; else
      log "Warning: nvim not found; skipping plugin sync."
      return 0
    fi
  fi

  log "Installing/updating plugins (headless)…"
  run_as_target "$nvim_bin" --headless "+Lazy! sync" "+qa"

  log "Waiting for Mason installs to finish (headless)…"
  local tmp lua_file
  tmp="$(run_as_target mktemp -d)"
  CLEANUP_DIRS+=("$tmp")
  lua_file="$tmp/wait_mason.lua"

  # Write Lua script to file (no shell expansion)
  cat >"$lua_file" <<'LUA'
local ok, registry = pcall(require, "mason-registry")
if not ok then
  -- Mason not installed/loaded; nothing to wait for
  vim.cmd("qa")
  return
end

local function any_installing()
  registry.refresh() -- best-effort
  for _, pkg in ipairs(registry.get_installed_packages()) do
    if pkg:is_installing() then return true end
  end
  return false
end

local timeout = 300 -- seconds
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

  run_as_target "$nvim_bin" --headless -c "luafile $lua_file"
}

ensure_rustup() {
  if target_has_cmd cargo && target_has_cmd rustc; then
    local v
    v="$(run_as_target cargo --version | awk '{print $2}')"
    # If cargo is old, we’ll still install rustup below; easiest is just proceed if rustup exists
    if target_has_cmd rustup; then return 0; fi
  fi

  log "Installing Rust toolchain (rustup)…"
  need_cmd curl
  run_as_target bash -lc 'curl -fsSL https://sh.rustup.rs | sh -s -- -y'
  # Make sure rustup env is available for non-interactive shells
  run_as_target bash -lc 'mkdir -p "$HOME/.local/bin"; ln -sf "$HOME/.cargo/bin/cargo" "$HOME/.local/bin/cargo"; ln -sf "$HOME/.cargo/bin/rustc" "$HOME/.local/bin/rustc"'
  # Ensure stable is installed/selected
  run_as_target bash -lc '"$HOME/.cargo/bin/rustup" default stable'
}

ensure_grip_grab() {
  if target_has_cmd gg; then return 0; fi
  if ! target_has_cmd cargo; then log "Warning: cargo not found; cannot install grip-grab/gg."; return 0; fi
  log "Installing grip-grab (gg) via cargo…"
  run_as_target bash -lc '"$HOME/.cargo/bin/cargo" install grip-grab'
  # Ensure gg is discoverable in subsequent commands
  run_as_target bash -lc 'mkdir -p "$HOME/.local/bin"; ln -sf "$HOME/.cargo/bin/gg" "$HOME/.local/bin/gg"'
}

CLEANUP_DIRS=()
cleanup() {
  for dir in "${CLEANUP_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

ensure_base_packages
ensure_node
ensure_poetry
ensure_fd
install_neovim

BOOTSTRAP_ROOT="$(resolve_bootstrap_root)"
install_config "$BOOTSTRAP_ROOT"
ensure_rustup
ensure_grip_grab
sync_plugins

log "Done."
