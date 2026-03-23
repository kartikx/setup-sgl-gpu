#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d%H%M%S)"

# Explicit list of tracked config files to install in $HOME.
CONFIG_FILES=(
  ".bashrc"
  ".gitconfig"
  ".p10k.zsh"
  ".zshrc"
)

copy_item() {
  local base="$1"
  local src="$REPO_DIR/$base"
  local dest="$HOME/$base"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    echo "Skipped missing source: $src"
    return 1
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "${dest}${BACKUP_SUFFIX}"
    echo "Backed up $dest -> ${dest}${BACKUP_SUFFIX}"
  fi

  cp -a "$src" "$dest"
  echo "Copied $src -> $dest"
  return 0
}

copied=0
for base in "${CONFIG_FILES[@]}"; do
  if copy_item "$base"; then
    copied=$((copied + 1))
  fi
done

echo "Done. Copied $copied config item(s) to $HOME."
