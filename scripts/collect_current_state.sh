#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT_DIR/reports"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$REPORT_DIR/current-state-$TS.md"

mkdir -p "$REPORT_DIR"

{
  echo "# Machine State Snapshot ($TS)"
  echo
  echo "## brew leaves"
  echo '```'
  brew leaves 2>/dev/null || true
  echo '```'
  echo
  echo "## brew casks"
  echo '```'
  brew list --cask 2>/dev/null || true
  echo '```'
  echo
  echo "## brew services"
  echo '```'
  brew services list 2>/dev/null || true
  echo '```'
  echo
  echo "## npm global"
  echo '```'
  npm list -g --depth=0 --location=global 2>/dev/null || true
  echo '```'
  echo
  echo "## zsh plugins from ~/.zshrc"
  echo '```'
  rg -n "plugins=|zsh-autosuggestions|zsh-syntax-highlighting|zsh-z|nvm|fzf" "$HOME/.zshrc" 2>/dev/null || true
  echo '```'
} > "$OUT"

echo "$OUT"
