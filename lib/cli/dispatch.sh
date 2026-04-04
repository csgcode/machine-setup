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
      log_error "Unknown subcommand: $CLI_SUBCOMMAND"
      cli_usage
      return 1
      ;;
  esac
}
