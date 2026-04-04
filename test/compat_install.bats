#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "run_eval prints dry-run command without executing it" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    SETUP_DRY_RUN=1
    run_eval "echo hello"
  '
  [ "$status" -eq 0 ]
  [ "$output" = '[DRY-RUN] echo hello' ]
}

@test "compat install suppresses duplicate dependency execution" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/compat/install.sh"

    package_exists() { return 0; }
    package_dependencies() {
      case "$1" in
        root) printf "%s\n" left right ;;
        left) printf "%s\n" shared ;;
        right) printf "%s\n" shared ;;
      esac
    }
    package_field() {
      case "$2" in
        manager) printf "%s\n" brew_formula ;;
        check) printf "%s\n" false ;;
        install) printf "%s\n" "$1" ;;
        service) printf "%s\n" ;;
      esac
    }
    brew_install_formula() { :; }
    brew_install_cask() { :; }
    install_oh_my_zsh() { :; }
    install_zsh_plugin() { :; }
    install_fzf_extras() { :; }

    compat_reset_install_state
    compat_install_package root
  '
  [ "$status" -eq 0 ]
  [ "$(count_matches '[INFO] Installing: shared' "$output")" -eq 1 ]
}

@test "compat install reports readable circular dependency paths" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/compat/install.sh"

    package_exists() { return 0; }
    package_dependencies() {
      case "$1" in
        a) printf "%s\n" b ;;
        b) printf "%s\n" c ;;
        c) printf "%s\n" a ;;
      esac
    }
    package_field() {
      case "$2" in
        manager) printf "%s\n" brew_formula ;;
        check) printf "%s\n" false ;;
        install) printf "%s\n" "$1" ;;
        service) printf "%s\n" ;;
      esac
    }
    brew_install_formula() { :; }
    brew_install_cask() { :; }
    install_oh_my_zsh() { :; }
    install_zsh_plugin() { :; }
    install_fzf_extras() { :; }

    compat_reset_install_state
    compat_install_package a
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'Circular dependency detected: a -> b -> c -> a'* ]]
}
