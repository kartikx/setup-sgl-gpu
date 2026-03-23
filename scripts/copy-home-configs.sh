#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_SUFFIX=".backup.$(date +%Y%m%d%H%M%S)"

# Top-level dotfiles in this repo are treated as home config files, with a few
# repo-specific entries excluded.
EXCLUDES=(
  ".git"
  ".github"
  ".gitignore"
  ".gitattributes"
  ".DS_Store"
)

should_exclude() {
  local name="$1"
  for excluded in "${EXCLUDES[@]}"; do
    if [[ "$name" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

copy_item() {
  local src="$1"
  local base
  base="$(basename "$src")"
  local dest="$HOME/$base"

  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "${dest}${BACKUP_SUFFIX}"
    echo "Backed up $dest -> ${dest}${BACKUP_SUFFIX}"
  fi

  cp -a "$src" "$dest"
  echo "Copied $src -> $dest"
}

copied=0
while IFS= read -r -d '' path; do
  base="$(basename "$path")"
  if should_exclude "$base"; then
    continue
  fi
  copy_item "$path"
  copied=$((copied + 1))
done < <(find "$REPO_DIR" -mindepth 1 -maxdepth 1 -name ".*" -print0)

echo "Done. Copied $copied config item(s) to $HOME."
