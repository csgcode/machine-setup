#!/usr/bin/env bash

dispatch_cli() {
  case "$CLI_SUBCOMMAND" in
    menu)
      compat_show_menu
      ;;
    list)
      cmd_list
      ;;
    doctor)
      cmd_doctor
      ;;
    install)
      cmd_install_legacy
      ;;
    *)
      cli_usage_error "Unknown subcommand: $CLI_SUBCOMMAND"
      return $?
      ;;
  esac
}
