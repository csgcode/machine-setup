#!/usr/bin/env bash

CLI_SUBCOMMAND="menu"
CLI_GROUP=""
CLI_PACKAGE=""
CLI_SHOW_HELP=0

CLI_EXIT_OK=0
CLI_EXIT_RUNTIME_ERROR=1
CLI_EXIT_USAGE_ERROR=2

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

cli_usage_error() {
  log_error "$1"
  cli_usage
  return "$CLI_EXIT_USAGE_ERROR"
}

parse_cli_args() {
  CLI_SUBCOMMAND="menu"
  CLI_GROUP=""
  CLI_PACKAGE=""
  CLI_SHOW_HELP=0

  if [[ $# -gt 0 ]] && [[ "$1" != --* ]]; then
    CLI_SUBCOMMAND="$1"
    shift
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --group)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          cli_usage_error "Missing value for --group"
          return $?
        fi
        CLI_GROUP="$2"
        shift 2
        ;;
      --package)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          cli_usage_error "Missing value for --package"
          return $?
        fi
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
        CLI_SHOW_HELP=1
        cli_usage
        return "$CLI_EXIT_OK"
        ;;
      *)
        cli_usage_error "Unknown argument: $1"
        return $?
        ;;
    esac
  done

  case "$CLI_SUBCOMMAND" in
    menu|list|doctor)
      if [[ -n "$CLI_GROUP" || -n "$CLI_PACKAGE" ]]; then
        cli_usage_error "Selectors are only supported with the install subcommand"
        return $?
      fi
      ;;
    install)
      ;;
    *)
      ;;
  esac
}
