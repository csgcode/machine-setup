#!/usr/bin/env bash

cmd_install() {
  local selection_args=()
  local plan=()

  if [[ -n "$CLI_GROUP" ]] && [[ "${#CLI_PACKAGES[@]}" -gt 0 || "${#CLI_TAGS[@]}" -gt 0 || "${#CLI_PROFILES[@]}" -gt 0 ]]; then
    log_error "Use either --group or package/tag/profile selectors, not both"
    return 2
  fi

  if [[ -n "$CLI_GROUP" ]]; then
    log_warn "Using legacy compatibility path: install --group"
    compat_install_group "$CLI_GROUP"
    return $?
  fi

  read_lines_into_array selection_args executor_selection_args
  if [[ "${#selection_args[@]}" -eq 0 ]]; then
    log_error "install requires --package, --tag, --profile, or --group"
    return 2
  fi

  read_lines_into_array plan planner_build_install_plan_from_inputs "${selection_args[@]}" || return 1
  if [[ "${#plan[@]}" -eq 0 ]]; then
    log_warn "No actions planned for the selected packages"
    return 0
  fi
  executor_execute_plan "install" "${plan[@]}"
}

cmd_check() {
  local selection_args=()
  local resolved=()
  local status=0
  local pkg

  if [[ -n "$CLI_GROUP" ]]; then
    log_error "--group is only supported by the legacy install compatibility path"
    return 2
  fi

  read_lines_into_array selection_args executor_selection_args
  if [[ "${#selection_args[@]}" -eq 0 ]]; then
    log_error "check requires --package, --tag, or --profile"
    return 2
  fi

  read_lines_into_array resolved selection_resolve_inputs "${selection_args[@]}" || return 1
  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No packages resolved from the requested selectors"
    return 0
  fi
  for pkg in "${resolved[@]}"; do
    [[ -z "$pkg" ]] && continue
    if ! executor_check_package "$pkg"; then
      status=1
    fi
  done

  return "$status"
}

cmd_apply_config() {
  local selection_args=()
  local plan=()

  if [[ -n "$CLI_GROUP" ]]; then
    log_error "--group is only supported by the legacy install compatibility path"
    return 2
  fi

  read_lines_into_array selection_args executor_selection_args
  if [[ "${#selection_args[@]}" -eq 0 ]]; then
    log_error "apply-config requires --package, --tag, or --profile"
    return 2
  fi

  read_lines_into_array plan planner_build_install_plan_from_inputs "${selection_args[@]}" || return 1
  if [[ "${#plan[@]}" -eq 0 ]]; then
    log_warn "No config actions planned for the selected packages"
    return 0
  fi
  executor_execute_plan "apply-config" "${plan[@]}"
}
