#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SETUP_DRY_RUN=0
SETUP_YES=0
SETUP_VERBOSE=0

source "$ROOT_DIR/lib/common/log.sh"
source "$ROOT_DIR/lib/common/checks.sh"
source "$ROOT_DIR/lib/cli/args.sh"
source "$ROOT_DIR/lib/cli/dispatch.sh"
source "$ROOT_DIR/lib/commands/system.sh"
source "$ROOT_DIR/lib/compat/install.sh"
source "$ROOT_DIR/lib/compat/menu.sh"
source "$ROOT_DIR/lib/core/selection.sh"
source "$ROOT_DIR/lib/manifest.sh"
source "$ROOT_DIR/lib/installers/brew.sh"
source "$ROOT_DIR/lib/installers/shell.sh"

main() {
  export SETUP_DRY_RUN SETUP_YES SETUP_VERBOSE ROOT_DIR
  parse_cli_args "$@" || return $?
  if [[ "$CLI_SHOW_HELP" -eq 1 ]]; then
    return 0
  fi
  dispatch_cli
}
