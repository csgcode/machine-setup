#!/usr/bin/env bash

executor_selection_args() {
  local args=()
  local index
  local pkg
  local tag

  for index in "${!CLI_PACKAGES[@]}"; do
    pkg="${CLI_PACKAGES[$index]}"
    args+=("--package" "$pkg")
  done

  for index in "${!CLI_TAGS[@]}"; do
    tag="${CLI_TAGS[$index]}"
    args+=("--tag" "$tag")
  done

  printf '%s\n' "${args[@]}"
}

executor_check_package() {
  local pkg="$1"
  local check_cmd=""

  check_cmd="$(package_check_command "$pkg" | head -n1)"
  if [[ -n "$check_cmd" ]] && eval "$check_cmd"; then
    printf '[ok] %s\n' "$pkg"
    return 0
  fi

  printf '[missing] %s\n' "$pkg"
  return 1
}

executor_install_package_action() {
  local pkg="$1"
  local kind="$2"
  local target="$3"

  case "$kind" in
    brew_formula)
      brew_install_formula "$target"
      ;;
    brew_cask)
      brew_install_cask "$target"
      ;;
    shell_component)
      shell_component_install "$target"
      ;;
    *)
      log_error "Unknown installer kind '$kind' for package '$pkg'"
      return 1
      ;;
  esac
}

executor_execute_plan() {
  local mode="$1"
  shift
  local line action pkg field3 field4 field5

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r action pkg field3 field4 field5 <<< "$line"

    case "$action" in
      package)
        if [[ "$mode" == "apply-config" ]]; then
          continue
        fi

        if executor_check_package "$pkg" >/dev/null 2>&1; then
          log_info "Already installed: $pkg"
          continue
        fi

        log_info "Installing: $pkg"
        executor_install_package_action "$pkg" "$field3" "$field4" || return 1
        ;;
      config)
        case "$field3" in
          chezmoi_tag)
            if [[ "$field5" == "true" ]]; then
              chezmoi_apply_targets --optional "$field4" || return 1
            else
              chezmoi_apply_targets "$field4" || return 1
            fi
            ;;
          *)
            log_error "Unsupported config strategy '$field3' for package '$pkg'"
            return 1
            ;;
        esac
        ;;
      manual_step)
        printf '[manual] %s: %s\n' "$pkg" "$field3"
        ;;
      *)
        log_error "Unknown plan action '$action'"
        return 1
        ;;
    esac
  done < <(printf '%s\n' "$@")
}
