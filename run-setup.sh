#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[run-setup] Running install.sh..."
bash "${REPO_DIR}/install.sh"

echo "[run-setup] Running scripts/copy-home-configs.sh..."
bash "${REPO_DIR}/scripts/copy-home-configs.sh"

echo "[run-setup] Done."
echo "[run-setup] For a fresh login shell, run: exit  (then SSH back in)."
exit 0
