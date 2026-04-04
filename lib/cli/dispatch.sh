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
    install)
      cmd_install
      ;;
    check)
      cmd_check
      ;;
    apply-config)
      cmd_apply_config
      ;;
    *)
      cli_usage_error "Unknown subcommand: $CLI_SUBCOMMAND"
      return $?
      ;;
  esac
}
