#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GITHUB_SSH_KEY_PATH="${GITHUB_SSH_KEY_PATH:-$HOME/.ssh/id_ed25519_github}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_DOTFILES="${INSTALL_DOTFILES:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-1}"

log() {
  echo "[setup-cpu] $*"
}

fail() {
  echo "[setup-cpu] ERROR: $*" >&2
  exit 1
}

require_github_key() {
  if [[ ! -f "$GITHUB_SSH_KEY_PATH" ]]; then
    fail "Expected GitHub SSH key at $GITHUB_SSH_KEY_PATH. Run ./generate-keys.sh first, add the printed public key to GitHub, then rerun this script."
  fi
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv already installed"
    return
  fi

  log "Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_codex() {
  if [[ "$INSTALL_CODEX" != "1" ]]; then
    log "Skipping Codex CLI install because INSTALL_CODEX=$INSTALL_CODEX"
    return
  fi

  if command -v codex >/dev/null 2>&1; then
    log "Codex CLI already installed"
    return
  fi

  log "Installing Codex CLI"
  sudo npm i -g @openai/codex
}

install_fzf() {
  if command -v fzf >/dev/null 2>&1; then
    log "fzf already installed"
    return
  fi

  log "Installing fzf"
  local archive="fzf-0.67.0-linux_amd64.tar.gz"
  local temp_dir
  temp_dir="$(mktemp -d)"
  wget -O "${temp_dir}/${archive}" "https://github.com/junegunn/fzf/releases/download/v0.67.0/${archive}"
  tar -xzf "${temp_dir}/${archive}" -C "$temp_dir"
  sudo mv "${temp_dir}/fzf" /usr/local/bin/fzf
  rm -rf "$temp_dir"
}

install_zoxide() {
  if command -v zoxide >/dev/null 2>&1; then
    log "zoxide already installed"
    return
  fi

  log "Installing zoxide"
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
}

install_neovim() {
  if command -v nvim >/dev/null 2>&1; then
    log "neovim already installed"
    return
  fi

  log "Installing neovim"
  local archive="nvim-linux-x86_64.tar.gz"
  local temp_dir
  temp_dir="$(mktemp -d)"
  wget -O "${temp_dir}/${archive}" "https://github.com/neovim/neovim/releases/latest/download/${archive}"
  sudo rm -rf /opt/nvim-linux-x86_64
  sudo tar -C /opt -xzf "${temp_dir}/${archive}"
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm -rf "$temp_dir"
}

install_dotfiles() {
  if [[ "$INSTALL_DOTFILES" != "1" ]]; then
    log "Skipping dotfiles because INSTALL_DOTFILES=$INSTALL_DOTFILES"
    return
  fi

  log "Copying tracked home configs"
  bash "$REPO_DIR/scripts/copy-home-configs.sh"

  if [[ "$SET_DEFAULT_SHELL" == "1" ]]; then
    log "Setting default shell to zsh"
    sudo chsh -s "$(command -v zsh)" "$USER"
  fi
}

main() {
  require_github_key

  log "Installing base packages"
  sudo apt update
  sudo apt install -y \
    build-essential \
    ca-certificates \
    curl \
    git \
    nodejs \
    npm \
    wget \
    zsh

  install_uv
  export PATH="$HOME/.local/bin:$PATH"
  install_fzf
  install_zoxide
  install_neovim
  install_codex
  install_dotfiles

  log "CPU setup complete"
  log "For a fresh login shell, run: exit  (then SSH back in)."
}

main "$@"
