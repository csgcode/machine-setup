#!/usr/bin/env bash

CLI_SUBCOMMAND="menu"
CLI_GROUP=""
CLI_PACKAGES=()
CLI_TAGS=()
CLI_PROFILES=()
CLI_SHOW_HELP=0
CLI_OUTPUT_FORMAT="text"

CLI_EXIT_OK=0
CLI_EXIT_RUNTIME_ERROR=1
CLI_EXIT_USAGE_ERROR=2

cli_usage() {
  cat <<USAGE
machine-setup: declarative macOS bootstrap for packages and chezmoi-managed config

Use:
  setup                         Guided interactive flow for human-driven setup
  setup list                    Show packages known to this repo
  setup doctor                  Check local prerequisites before bootstrap/install
  setup bootstrap               Install and initialize chezmoi if needed
  setup status                  Compare saved desired state with installed software
  setup install ...             Install selected software and apply linked config
  setup check ...               Check whether selected software is installed
  setup apply-config ...        Re-apply config only for selected software
  setup drift ...               Report chezmoi config drift for selected software

Selectors:
  --package <id>                Select one package, repeatable
  --tag <tag>                   Select a logical package group, repeatable
  --profile <id>                Select a repo-defined profile, repeatable
  --group <name>                Legacy compatibility path for install only

Formats:
  --format text|json            Supported by list, doctor, status, drift, bootstrap

Flags:
  --dry-run                     Preview mutating operations without changing the machine
  --yes                         Non-interactive mode where prompts would normally appear
  --verbose                     More detailed logging
  -h, --help                    Show this help

Command Syntax:
  setup [menu] [--dry-run] [--yes] [--verbose]
  setup [subcommand] [--format <text|json>]
  setup install --package <id> [--package <id> ...] [--tag <tag> ...] [--profile <id> ...]
  setup install --group <name>
  setup check --package <id> [--tag <tag> ...] [--profile <id> ...]
  setup apply-config --package <id> [--tag <tag> ...] [--profile <id> ...]
  setup drift --package <id> [--tag <tag> ...] [--profile <id> ...]

Common Workflows:
  setup doctor
  setup bootstrap
  setup
  setup install --tag shell
  setup check --profile work-laptop
  setup status
  setup drift --tag shell
  setup status --format json

Notes:
  install applies linked config by default
  status shows what is missing from saved desired state on this machine
  list shows what this repo can manage
  drift checks config state through chezmoi
  prefer package/tag/profile selectors for new usage
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
  CLI_PACKAGES=()
  CLI_TAGS=()
  CLI_PROFILES=()
  CLI_SHOW_HELP=0
  CLI_OUTPUT_FORMAT="text"

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
        CLI_PACKAGES+=("$2")
        shift 2
        ;;
      --tag)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          cli_usage_error "Missing value for --tag"
          return $?
        fi
        CLI_TAGS+=("$2")
        shift 2
        ;;
      --profile)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          cli_usage_error "Missing value for --profile"
          return $?
        fi
        CLI_PROFILES+=("$2")
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
      --format)
        if [[ $# -lt 2 || "$2" == --* ]]; then
          cli_usage_error "Missing value for --format"
          return $?
        fi
        case "$2" in
          text|json)
            CLI_OUTPUT_FORMAT="$2"
            ;;
          *)
            cli_usage_error "Unsupported format: $2"
            return $?
            ;;
        esac
        shift 2
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
    menu|list|doctor|status|bootstrap)
      if [[ -n "$CLI_GROUP" || "${#CLI_PACKAGES[@]}" -gt 0 || "${#CLI_TAGS[@]}" -gt 0 || "${#CLI_PROFILES[@]}" -gt 0 ]]; then
        cli_usage_error "Selectors are only supported with install, check, apply-config, and drift"
        return $?
      fi
      ;;
    check|apply-config|drift)
      if [[ -n "$CLI_GROUP" ]]; then
        cli_usage_error "--group is only supported with install"
        return $?
      fi
      ;;
    install)
      ;;
    *)
      ;;
  esac
}
