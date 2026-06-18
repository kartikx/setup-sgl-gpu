#!/usr/bin/env bash
set -euo pipefail

NVM_VERSION="${NVM_VERSION:-v0.40.3}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

log() {
  echo "[install-codex] $*"
}

if [[ -x "${NVM_DIR}/versions/node" ]] && command -v codex >/dev/null 2>&1; then
  log "Codex CLI already installed"
  exit 0
fi

log "Installing nvm ${NVM_VERSION}"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash

export NVM_DIR
# shellcheck disable=SC1090
source "${NVM_DIR}/nvm.sh"

log "Installing Node.js LTS via nvm"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

log "Installing Codex CLI"
npm install -g @openai/codex

log "Done."
