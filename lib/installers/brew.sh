#!/usr/bin/env bash
set -euo pipefail

brew_install_formula() {
  local name="$1"
  run_eval "brew list --formula '$name' >/dev/null 2>&1 || brew install '$name'"
}

brew_install_cask() {
  local name="$1"
  run_eval "brew list --cask '$name' >/dev/null 2>&1 || brew install --cask '$name'"
}

brew_service_start() {
  local name="$1"
  run_eval "brew services list | awk '{print \$1" "\$2}' | rg -q '^${name} started$' || brew services start '$name'"
}
