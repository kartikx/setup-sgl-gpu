#!/usr/bin/env bash
set -euo pipefail

ZSHRC_PATH="${ZSHRC_PATH:-$HOME/.zshrc}"
TOKEN="${1:-${HF_TOKEN:-}}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <hf_token>

Or:
  HF_TOKEN=<hf_token> $(basename "$0")

Optional environment override:
  ZSHRC_PATH   Default: \$HOME/.zshrc
EOF
}

if [[ -z "$TOKEN" ]]; then
  usage
  exit 1
fi

mkdir -p "$(dirname "$ZSHRC_PATH")"
touch "$ZSHRC_PATH"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

grep -v '^export HF_TOKEN=' "$ZSHRC_PATH" > "$tmp_file" || true
printf '\nexport HF_TOKEN=%q\n' "$TOKEN" >> "$tmp_file"
mv "$tmp_file" "$ZSHRC_PATH"

echo "Updated $ZSHRC_PATH with HF_TOKEN."
echo "Run: source \"$ZSHRC_PATH\""
