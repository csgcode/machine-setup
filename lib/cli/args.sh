#!/usr/bin/env bash

CLI_SUBCOMMAND="menu"
CLI_GROUP=""
CLI_PACKAGE=""

cli_usage() {
  cat <<USAGE
Usage:
  setup [menu] [--dry-run] [--yes] [--verbose]
  setup list
  setup doctor
  setup install --package <id>
  setup install --group <name>    # legacy compatibility path

Examples:
  setup
  setup list
  setup doctor
  setup install --package oh-my-zsh
  setup install --group shell --dry-run
USAGE
}

parse_cli_args() {
  CLI_SUBCOMMAND="menu"
  CLI_GROUP=""
  CLI_PACKAGE=""

  if [[ $# -gt 0 ]] && [[ "$1" != --* ]]; then
    CLI_SUBCOMMAND="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group)
        CLI_GROUP="$2"
        shift 2
        ;;
      --package)
        CLI_PACKAGE="$2"
        shift 2
        ;;
      --dry-run)
        SETUP_DRY_RUN=1
        shift
        ;;
      --yes)
        SETUP_YES=1
        shift
        ;;
      --verbose)
        SETUP_VERBOSE=1
        shift
        ;;
      -h|--help)
        cli_usage
        return 1
        ;;
      *)
        log_error "Unknown argument: $1"
        cli_usage
        return 2
        ;;
    esac
  done
}
