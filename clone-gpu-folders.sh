#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/mnt/data}"
ENV_DIR="${ENV_DIR:-${BASE_DIR}/envs/sgl-a100}"
BENCHMARKING_DIR="${BENCHMARKING_DIR:-${BASE_DIR}/sglang-nixl-benchmarking}"
SGLANG_DIR="${SGLANG_DIR:-${BASE_DIR}/sglang}"
SGLANG_BRANCH="kartikx/pd-disagg"
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
  mkdir -p "$(dirname "$repo_dir")"
  git clone "$repo_url" "$repo_dir"
}

ensure_branch() {
  local repo_dir="$1"
  local branch="$2"

  log "Ensuring branch ${branch} in ${repo_dir}"
  git -C "$repo_dir" fetch origin

  if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/${branch}"; then
    git -C "$repo_dir" checkout "$branch"
  else
    git -C "$repo_dir" checkout -b "$branch" --track "origin/${branch}"
  fi

  git -C "$repo_dir" pull --ff-only origin "$branch"
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

clone_or_update_repo "git@github.com:kartikx/sglang-nixl-benchmarking.git" "$BENCHMARKING_DIR"
clone_or_update_repo "git@github.com:kartikx/sglang.git" "$SGLANG_DIR"
ensure_branch "$SGLANG_DIR" "$SGLANG_BRANCH"

if [[ -x "${ENV_DIR}/bin/python" ]]; then
  log "Using existing venv: ${ENV_DIR}"
else
  log "Creating venv: ${ENV_DIR}"
  mkdir -p "${BASE_DIR}/envs"
  "$UV_BIN" venv --python 3.12 "$ENV_DIR"
fi

# shellcheck disable=SC1091
source "${ENV_DIR}/bin/activate"

log "Done."
