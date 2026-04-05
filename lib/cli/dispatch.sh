#!/usr/bin/env bash

dispatch_cli() {
  case "$CLI_SUBCOMMAND" in
    menu)
      cmd_interactive
      ;;
    list)
      cmd_list
      ;;
    doctor)
      cmd_doctor
      ;;
    bootstrap)
      cmd_bootstrap
      ;;
    status)
      cmd_status
      ;;
    install)
      cmd_install
      ;;
    check)
      cmd_check
      ;;
    apply-config)
      cmd_apply_config
      ;;
    drift)
      cmd_drift
      ;;
    *)
      cli_usage_error "Unknown subcommand: $CLI_SUBCOMMAND"
      return $?
      ;;
  esac
}
