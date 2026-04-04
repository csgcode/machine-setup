#!/usr/bin/env bash

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

  if ! PKG="$pkg" package_exists "$pkg"; then
    log_error "Unknown package: $pkg"
    return 1
  fi

  mapfile -t deps < <(package_dependencies "$pkg")
  for dep in "${deps[@]}"; do
    [[ -z "$dep" ]] && continue
    compat_install_package "$dep"
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
          zshrc-curated)
            apply_dotfile_mapping
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
        log_error "Unknown manager '$manager' for package '$pkg'"
        return 1
        ;;
    esac
  fi

  if [[ -n "$service_name" ]]; then
    log_info "Starting service: $service_name"
    brew_service_start "$service_name"
  fi
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

  for pkg in "${pkgs[@]}"; do
    [[ -z "$pkg" ]] && continue
    compat_install_package "$pkg"
  done
}

cmd_install_legacy() {
  if [[ -n "$CLI_GROUP" && -n "$CLI_PACKAGE" ]]; then
    log_error "Use either --group or --package, not both"
    return 1
  fi

  if [[ -n "$CLI_GROUP" ]]; then
    log_warn "Using legacy compatibility path: install --group"
    compat_install_group "$CLI_GROUP"
    return $?
  fi

  if [[ -n "$CLI_PACKAGE" ]]; then
    compat_install_package "$CLI_PACKAGE"
    return $?
  fi

  log_error "install requires --group or --package"
  return 1
}
