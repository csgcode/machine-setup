#!/usr/bin/env bash

COMPAT_INSTALL_DONE=()
COMPAT_INSTALL_STACK=()

compat_reset_install_state() {
  COMPAT_INSTALL_DONE=()
  COMPAT_INSTALL_STACK=()
}

compat_array_contains() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

compat_mark_installed() {
  local pkg="$1"
  COMPAT_INSTALL_DONE+=("$pkg")
}

compat_push_stack() {
  local pkg="$1"
  COMPAT_INSTALL_STACK+=("$pkg")
}

compat_pop_stack() {
  local last_index
  last_index=$((${#COMPAT_INSTALL_STACK[@]} - 1))
  unset 'COMPAT_INSTALL_STACK[last_index]'
}

compat_format_cycle() {
  local pkg="$1"
  local started=0
  local path=()
  local item

  for item in "${COMPAT_INSTALL_STACK[@]}"; do
    if [[ "$item" == "$pkg" ]]; then
      started=1
    fi
    if [[ "$started" -eq 1 ]]; then
      path+=("$item")
    fi
  done

  path+=("$pkg")

  local joined=""
  for item in "${path[@]}"; do
    if [[ -n "$joined" ]]; then
      joined="$joined -> "
    fi
    joined="$joined$item"
  done

  printf '%s\n' "$joined"
}

compat_confirm_or_skip() {
  local prompt="$1"
  if [[ "$SETUP_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " response
  [[ "$response" =~ ^[Yy]$ ]]
}

compat_install_package() {
  local pkg="$1"

  if compat_array_contains "$pkg" "${COMPAT_INSTALL_DONE[@]}"; then
    log_debug "Skipping already processed package: $pkg"
    return 0
  fi

  if compat_array_contains "$pkg" "${COMPAT_INSTALL_STACK[@]}"; then
    log_error "Circular dependency detected: $(compat_format_cycle "$pkg")"
    return 1
  fi

  if ! PKG="$pkg" package_exists "$pkg"; then
    log_error "Unknown package: $pkg"
    return 1
  fi

  compat_push_stack "$pkg"

  mapfile -t deps < <(package_dependencies "$pkg")
  for dep in "${deps[@]}"; do
    [[ -z "$dep" ]] && continue
    if ! compat_install_package "$dep"; then
      compat_pop_stack
      return 1
    fi
  done

  local manager check_cmd install_cmd service_name
  manager="$(package_field "$pkg" manager | head -n1)"
  check_cmd="$(package_field "$pkg" check | head -n1)"
  install_cmd="$(package_field "$pkg" install | head -n1)"
  service_name="$(package_field "$pkg" service | head -n1)"

  if [[ -n "$check_cmd" ]] && eval "$check_cmd"; then
    log_info "Already installed: $pkg"
  else
    log_info "Installing: $pkg"
    case "$manager" in
      brew_formula)
        brew_install_formula "$install_cmd"
        ;;
      brew_cask)
        brew_install_cask "$install_cmd"
        ;;
      shell_component)
        case "$pkg" in
          oh-my-zsh)
            install_oh_my_zsh
            ;;
          zsh-syntax-highlighting)
            install_zsh_plugin "https://github.com/zsh-users/zsh-syntax-highlighting.git" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
            ;;
          zsh-autosuggestions-plugin)
            install_zsh_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
            ;;
          zsh-z)
            install_zsh_plugin "https://github.com/agkozak/zsh-z" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-z"
            ;;
          fzf-extra)
            install_fzf_extras
            ;;
          *)
            log_error "Unknown shell component handler for $pkg"
            return 1
            ;;
        esac
        ;;
      *)
        compat_pop_stack
        log_error "Unknown manager '$manager' for package '$pkg'"
        return 1
        ;;
    esac
  fi

  if [[ -n "$service_name" ]]; then
    log_info "Starting service: $service_name"
    brew_service_start "$service_name"
  fi

  compat_pop_stack
  compat_mark_installed "$pkg"
}

compat_install_group() {
  local group="$1"
  mapfile -t pkgs < <(GROUP="$group" list_group_packages "$group")

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    log_error "Unknown or empty group: $group"
    return 1
  fi

  if ! compat_confirm_or_skip "Install group '$group'?"; then
    log_warn "Skipped group '$group'"
    return 0
  fi

  compat_reset_install_state

  for pkg in "${pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    compat_install_package "$pkg" || return 1
  done
}

cmd_install_legacy() {
  if [[ -n "$CLI_GROUP" && -n "$CLI_PACKAGE" ]]; then
    log_error "Use either --group or --package, not both"
    return 2
  fi

  if [[ -n "$CLI_GROUP" ]]; then
    log_warn "Using legacy compatibility path: install --group"
    compat_install_group "$CLI_GROUP"
    return $?
  fi

  if [[ -n "$CLI_PACKAGE" ]]; then
    compat_reset_install_state
    compat_install_package "$CLI_PACKAGE"
    return $?
  fi

  log_error "install requires --group or --package"
  return 2
}
