#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/mnt/data"
ENV_DIR="${BASE_DIR}/envs/sgl-a100"
SGLANG_DIR="${BASE_DIR}/sglang"
UV_BIN="${HOME}/.local/bin/uv"

log() {
  echo "[clone-gpu-folders] $*"
}

clone_or_update_repo() {
  local repo_url="$1"
  local repo_dir="$2"

  if [[ -d "${repo_dir}/.git" ]]; then
    log "Updating existing repo: ${repo_dir}"
    git -C "$repo_dir" pull --ff-only
    return
  fi

  if [[ -e "$repo_dir" ]]; then
    echo "Path exists and is not a git repo: $repo_dir"
    exit 1
  fi

  log "Cloning ${repo_url} -> ${repo_dir}"
  git clone "$repo_url" "$repo_dir"
}

if command -v uv >/dev/null 2>&1; then
  UV_BIN="$(command -v uv)"
elif [[ -x "$UV_BIN" ]]; then
  true
else
  echo "uv not found. Install uv first, then re-run."
  exit 1
fi

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

clone_or_update_repo "git@github.com:kartikx/sglang-nixl-benchmarking.git" "${BASE_DIR}/sglang-nixl-benchmarking"
clone_or_update_repo "git@github.com:kartikx/sglang.git" "$SGLANG_DIR"

if [[ -x "${ENV_DIR}/bin/python" ]]; then
  log "Using existing venv: ${ENV_DIR}"
else
  log "Creating venv: ${ENV_DIR}"
  mkdir -p "${BASE_DIR}/envs"
  "$UV_BIN" venv --python 3.12 "$ENV_DIR"
fi

# shellcheck disable=SC1091
source "${ENV_DIR}/bin/activate"

cd "$SGLANG_DIR"
uv pip install -e "python" --prerelease=allow
uv pip install --upgrade transformers

log "Done."
