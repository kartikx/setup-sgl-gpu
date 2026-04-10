#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASE_DIR="${BASE_DIR:-$HOME}"
ENV_DIR="${ENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
BENCHMARKING_DIR="${BENCHMARKING_DIR:-${BASE_DIR}/sglang-nixl-benchmarking}"
SGLANG_DIR="${SGLANG_DIR:-${BASE_DIR}/sglang}"
NIXL_DIR="${NIXL_DIR:-${BASE_DIR}/nixl}"
UCX_VERSION="${UCX_VERSION:-1.19.0}"
UCX_INSTALL_DIR="${UCX_INSTALL_DIR:-${BASE_DIR}/ucx-${UCX_VERSION}}"
GDRCOPY_DIR="${GDRCOPY_DIR:-${BASE_DIR}/gdrcopy}"
UCX_SRC_PARENT="${UCX_SRC_PARENT:-${BASE_DIR}/src}"
UCX_SRC_DIR="${UCX_SRC_DIR:-${UCX_SRC_PARENT}/ucx-${UCX_VERSION}}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_DOTFILES="${INSTALL_DOTFILES:-1}"
SET_DEFAULT_SHELL="${SET_DEFAULT_SHELL:-0}"
GENERATE_GITHUB_KEY="${GENERATE_GITHUB_KEY:-0}"
SKIP_GITHUB_CHECK="${SKIP_GITHUB_CHECK:-0}"

log() {
  echo "[bootstrap-gpu] $*"
}

fail() {
  echo "[bootstrap-gpu] ERROR: $*" >&2
  exit 1
}

set_zshrc_export() {
  local name="$1"
  local value="$2"
  local zshrc_path="${ZSHRC_PATH:-$HOME/.zshrc}"
  local tmp_file

  mkdir -p "$(dirname "$zshrc_path")"
  touch "$zshrc_path"

  tmp_file="$(mktemp)"
  grep -v "^export ${name}=" "$zshrc_path" > "$tmp_file" || true
  printf '\nexport %s=%q\n' "$name" "$value" >> "$tmp_file"
  mv "$tmp_file" "$zshrc_path"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <part1|part2|all>

Environment overrides:
  BASE_DIR            Default: \$HOME
  ENV_DIR             Default: \$BASE_DIR/envs/sgl-a100
  BENCHMARKING_DIR    Default: \$BASE_DIR/sglang-nixl-benchmarking
  SGLANG_DIR          Default: \$BASE_DIR/sglang
  NIXL_DIR            Default: \$BASE_DIR/nixl
  UCX_VERSION         Default: 1.19.0
  UCX_INSTALL_DIR     Default: \$BASE_DIR/ucx-\$UCX_VERSION
  GDRCOPY_DIR         Default: \$BASE_DIR/gdrcopy
  UCX_SRC_PARENT      Default: \$BASE_DIR/src
  UCX_SRC_DIR         Default: \$UCX_SRC_PARENT/ucx-\$UCX_VERSION
  CUDA_HOME           Default: /usr/local/cuda
  INSTALL_CODEX       Default: 1
  INSTALL_DOTFILES    Default: 1
  SET_DEFAULT_SHELL   Default: 0
  GENERATE_GITHUB_KEY Default: 0
  SKIP_GITHUB_CHECK   Default: 0
EOF
}

ensure_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
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

generate_github_key() {
  if [[ "$GENERATE_GITHUB_KEY" != "1" ]]; then
    log "Skipping GitHub SSH key generation because GENERATE_GITHUB_KEY=$GENERATE_GITHUB_KEY"
    return
  fi

  log "Generating GitHub SSH key via generate-keys.sh"
  bash "$REPO_DIR/generate-keys.sh"
  log "Add the printed public key to GitHub before running $(basename "$0") part2"
}

check_gpu_stack() {
  ensure_cmd git
  ensure_cmd curl
  ensure_cmd wget

  if ! command -v nvidia-smi >/dev/null 2>&1; then
    fail "nvidia-smi not found. Use a GPU-ready AMI or install NVIDIA drivers first."
  fi

  if [[ ! -d "$CUDA_HOME" ]]; then
    fail "CUDA_HOME does not exist at $CUDA_HOME. Set CUDA_HOME before running part2."
  fi
}

check_github_access() {
  if [[ "$SKIP_GITHUB_CHECK" == "1" ]]; then
    log "Skipping GitHub access check because SKIP_GITHUB_CHECK=1"
    return
  fi

  if git ls-remote git@github.com:kartikx/sglang.git >/dev/null 2>&1; then
    return
  fi

  fail "GitHub SSH access is not configured for git@github.com:kartikx/sglang.git. Configure your SSH key on this VM first, or rerun with SKIP_GITHUB_CHECK=1 if you know access works."
}

run_part1() {
  log "Installing base packages"
  sudo apt update
  sudo apt install -y \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    git \
    libibverbs-dev \
    libnuma-dev \
    libtool \
    ninja-build \
    nodejs \
    npm \
    pkg-config \
    rdma-core \
    wget \
    zsh

  install_uv
  export PATH="$HOME/.local/bin:$PATH"
  install_fzf
  install_zoxide
  install_neovim
  install_codex
  install_dotfiles
  generate_github_key

  log "part1 complete"
  log "Next: configure GitHub access and then run $(basename "$0") part2"
}

run_part2() {
  export PATH="$HOME/.local/bin:$PATH"

  ensure_cmd bash
  ensure_cmd sudo
  ensure_cmd git
  ensure_cmd wget
  ensure_cmd curl
  ensure_cmd uv

  check_gpu_stack
  check_github_access

  mkdir -p "$BASE_DIR"

  log "Running clone/setup with BASE_DIR=$BASE_DIR"
  BASE_DIR="$BASE_DIR" \
  ENV_DIR="$ENV_DIR" \
  BENCHMARKING_DIR="$BENCHMARKING_DIR" \
  SGLANG_DIR="$SGLANG_DIR" \
  bash "$REPO_DIR/clone-gpu-folders.sh"

  log "Recording SGLANG_VENV_PATH in ~/.zshrc"
  set_zshrc_export "SGLANG_VENV_PATH" "$ENV_DIR"

  log "Installing UCX into $UCX_INSTALL_DIR"
  BASE_DIR="$BASE_DIR" \
  UCX_VERSION="$UCX_VERSION" \
  UCX_INSTALL_DIR="$UCX_INSTALL_DIR" \
  GDRCOPY_DIR="$GDRCOPY_DIR" \
  UCX_SRC_PARENT="$UCX_SRC_PARENT" \
  UCX_SRC_DIR="$UCX_SRC_DIR" \
  CUDA_HOME="$CUDA_HOME" \
  bash "$REPO_DIR/install-ucx.sh"

  log "Installing NIXL into $ENV_DIR"
  BASE_DIR="$BASE_DIR" \
  UCX_VERSION="$UCX_VERSION" \
  UV_VENV_DIR="$ENV_DIR" \
  NIXL_DIR="$NIXL_DIR" \
  UCX_PATH="$UCX_INSTALL_DIR" \
  CUDA_HOME="$CUDA_HOME" \
  bash "$REPO_DIR/install-nixl.sh"

  log "Running smoke checks"
  # shellcheck disable=SC1090
  source "${ENV_DIR}/bin/activate"
  export LD_LIBRARY_PATH="${ENV_DIR}/lib:${ENV_DIR}/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
  nvidia-smi >/dev/null
  "${UCX_INSTALL_DIR}/bin/ucx_info" -d | grep -i cuda >/dev/null
  python -c "import nixl; import sglang; print('nixl and sglang imports ok')"

  log "part2 complete"
  log "Artifacts:"
  log "  ENV_DIR=$ENV_DIR"
  log "  SGLANG_DIR=$SGLANG_DIR"
  log "  NIXL_DIR=$NIXL_DIR"
  log "  UCX_INSTALL_DIR=$UCX_INSTALL_DIR"
}

main() {
  local mode="${1:-}"

  case "$mode" in
    part1)
      run_part1
      ;;
    part2)
      run_part2
      ;;
    all)
      run_part1
      run_part2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
