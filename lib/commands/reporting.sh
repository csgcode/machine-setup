#!/usr/bin/env bash

reporting_selection_args_or_error() {
  local selection_args=()

  if [[ -n "$CLI_GROUP" ]]; then
    log_error "--group is only supported by the legacy install compatibility path"
    return 2
  fi

  read_lines_into_array selection_args executor_selection_args
  if [[ "${#selection_args[@]}" -eq 0 ]]; then
    log_error "drift requires --package, --tag, or --profile"
    return 2
  fi

  printf '%s\n' "${selection_args[@]}"
}

reporting_config_status_for_package() {
  local pkg="$1"
  local strategy=""
  local target=""
  local status_line=()

  strategy="$(package_field "$pkg" "config.strategy" | head -n1)"
  target="$(package_field "$pkg" "config.target" | head -n1)"

  if [[ -z "$strategy" || -z "$target" ]]; then
    printf 'not-applicable\t%s\t%s\n' "$pkg" "-"
    printf 'No config target declared\n'
    return 0
  fi

  case "$strategy" in
    chezmoi_target)
      read_lines_into_array status_line chezmoi_target_status "$target" || return 1
      ;;
    *)
      printf 'unavailable\t%s\t%s\n' "$pkg" "$target"
      printf 'Unsupported config strategy %s\n' "$strategy"
      return 0
      ;;
  esac

  if [[ "${#status_line[@]}" -eq 0 ]]; then
    printf 'unavailable\t%s\t%s\n' "$pkg" "$target"
    printf 'No status returned from config backend\n'
    return 0
  fi

  printf '%s\t%s\t%s\n' "${status_line[0]}" "$pkg" "$target"
  if [[ "${#status_line[@]}" -gt 1 ]]; then
    printf '%s\n' "${status_line[@]:1}"
  fi
}

reporting_print_drift_summary() {
  local clean_count="$1"
  local drifted_count="$2"
  local unavailable_count="$3"
  local not_applicable_count="$4"

  printf 'Summary: clean=%s drifted=%s unavailable=%s not-applicable=%s\n' \
    "$clean_count" "$drifted_count" "$unavailable_count" "$not_applicable_count"
}

reporting_print_status_summary() {
  local desired_count="$1"
  local installed_desired_count="$2"
  local missing_desired_count="$3"
  local installed_unselected_count="$4"

  printf 'Summary: desired=%s installed=%s missing=%s installed-unselected=%s\n' \
    "$desired_count" \
    "$installed_desired_count" \
    "$missing_desired_count" \
    "$installed_unselected_count"
}

reporting_json_print_drift() {
  local packages_json="$1"
  local clean_count="$2"
  local drifted_count="$3"
  local unavailable_count="$4"
  local not_applicable_count="$5"
  local exit_status="$6"
  local warning="${7:-}"

  printf '{\n'
  printf '  "packages": %s,\n' "$packages_json"
  printf '  "summary": {"clean": %s, "drifted": %s, "unavailable": %s, "not_applicable": %s},\n' \
    "$clean_count" \
    "$drifted_count" \
    "$unavailable_count" \
    "$not_applicable_count"
  printf '  "exit_status": %s' "$exit_status"
  if [[ -n "$warning" ]]; then
    printf ',\n  "warning": %s\n' "$(output_json_string "$warning")"
  else
    printf '\n'
  fi
  printf '}\n'
}

reporting_json_print_status() {
  local desired_json="$1"
  local installed_unselected_json="$2"
  local desired_count="$3"
  local installed_desired_count="$4"
  local missing_desired_count="$5"
  local installed_unselected_count="$6"
  local exit_status="$7"
  local warning="${8:-}"

  printf '{\n'
  printf '  "desired_packages": %s,\n' "$desired_json"
  printf '  "installed_unselected": %s,\n' "$installed_unselected_json"
  printf '  "summary": {"desired": %s, "installed": %s, "missing": %s, "installed_unselected": %s},\n' \
    "$desired_count" \
    "$installed_desired_count" \
    "$missing_desired_count" \
    "$installed_unselected_count"
  printf '  "exit_status": %s' "$exit_status"
  if [[ -n "$warning" ]]; then
    printf ',\n  "warning": %s\n' "$(output_json_string "$warning")"
  else
    printf '\n'
  fi
  printf '}\n'
}

cmd_drift() {
  local selection_args=()
  local resolved=()
  local pkg=""
  local status_lines=()
  local status=""
  local target=""
  local detail=""
  local detail_lines=()
  local clean_count=0
  local drifted_count=0
  local unavailable_count=0
  local not_applicable_count=0
  local exit_status=0
  local package_results=()
  local detail_json=""

  read_lines_into_array selection_args reporting_selection_args_or_error || return $?
  read_lines_into_array resolved selection_resolve_direct_inputs "${selection_args[@]}" || return 1

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    if output_is_json; then
      reporting_json_print_drift "[]" 0 0 0 0 0 "No packages resolved from the requested selectors"
      return 0
    fi
    log_warn "No packages resolved from the requested selectors"
    return 0
  fi

  for pkg in "${resolved[@]}"; do
    [[ -z "$pkg" ]] && continue
    detail=""
    detail_lines=()
    read_lines_into_array status_lines reporting_config_status_for_package "$pkg" || return 1
    IFS=$'\t' read -r status _ target <<< "${status_lines[0]}"
    if [[ "${#status_lines[@]}" -gt 1 ]]; then
      detail_lines=("${status_lines[@]:1}")
      detail="$(printf '%s\n' "${detail_lines[@]}")"
    fi

    case "$status" in
      clean)
        clean_count=$((clean_count + 1))
        if ! output_is_json; then
          printf '[clean] %s (%s)\n' "$pkg" "$target"
        fi
        ;;
      drifted)
        drifted_count=$((drifted_count + 1))
        exit_status=1
        if ! output_is_json; then
          printf '[drifted] %s (%s)\n' "$pkg" "$target"
        fi
        if [[ -n "$detail" ]] && ! output_is_json; then
          printf '%s\n' "$detail"
        fi
        ;;
      unavailable)
        unavailable_count=$((unavailable_count + 1))
        if ! output_is_json; then
          printf '[unavailable] %s (%s): %s\n' "$pkg" "$target" "$detail"
        fi
        ;;
      not-applicable)
        not_applicable_count=$((not_applicable_count + 1))
        if ! output_is_json; then
          printf '[not-applicable] %s: %s\n' "$pkg" "$detail"
        fi
        ;;
      *)
        log_error "Unknown drift status '$status' for package '$pkg'"
        return 1
        ;;
    esac

    detail_json="$(output_json_string "$detail")"
    package_results+=("{\"package\":$(output_json_string "$pkg"),\"status\":$(output_json_string "$status"),\"target\":$(output_json_string "$target"),\"detail\":$detail_json}")
  done

  if output_is_json; then
    reporting_json_print_drift \
      "$(output_json_array "${package_results[@]}")" \
      "$clean_count" \
      "$drifted_count" \
      "$unavailable_count" \
      "$not_applicable_count" \
      "$exit_status"
    return "$exit_status"
  fi

  reporting_print_drift_summary \
    "$clean_count" \
    "$drifted_count" \
    "$unavailable_count" \
    "$not_applicable_count"

  return "$exit_status"
}

cmd_status() {
  local desired=()
  local installed_unselected=()
  local desired_pkg=""
  local pkg=""
  local desired_count=0
  local installed_desired_count=0
  local missing_desired_count=0
  local installed_unselected_count=0
  local exit_status=0
  local desired_results=()
  local unselected_results=()

  read_lines_into_array desired desired_state_resolve_packages || return 1
  if [[ "${#desired[@]}" -eq 0 ]]; then
    if output_is_json; then
      reporting_json_print_status "[]" "[]" 0 0 0 0 0 "No desired state is configured. Save a selection or set a profile first."
      return 0
    fi
    log_warn "No desired state is configured. Save a selection or set a profile first."
    return 0
  fi

  desired_count="${#desired[@]}"
  if ! output_is_json; then
    printf 'Desired packages:\n'
    for desired_pkg in "${desired[@]}"; do
      printf '  - %s\n' "$desired_pkg"
    done
  fi

  for desired_pkg in "${desired[@]}"; do
    if executor_package_installed "$desired_pkg"; then
      installed_desired_count=$((installed_desired_count + 1))
      if ! output_is_json; then
        printf '[desired-installed] %s\n' "$desired_pkg"
      fi
      desired_results+=("{\"package\":$(output_json_string "$desired_pkg"),\"status\":$(output_json_string "installed")}")
    else
      missing_desired_count=$((missing_desired_count + 1))
      exit_status=1
      if ! output_is_json; then
        printf '[desired-missing] %s\n' "$desired_pkg"
      fi
      desired_results+=("{\"package\":$(output_json_string "$desired_pkg"),\"status\":$(output_json_string "missing")}")
    fi
  done

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if selection_array_contains "$pkg" "${desired[@]+"${desired[@]}"}"; then
      continue
    fi
    if executor_package_installed "$pkg"; then
      installed_unselected+=("$pkg")
    fi
  done < <(list_all_packages)

  installed_unselected_count="${#installed_unselected[@]}"
  for pkg in "${installed_unselected[@]+"${installed_unselected[@]}"}"; do
    if ! output_is_json; then
      printf '[installed-unselected] %s\n' "$pkg"
    fi
    unselected_results+=("{\"package\":$(output_json_string "$pkg")}")
  done

  if output_is_json; then
    reporting_json_print_status \
      "$(output_json_array "${desired_results[@]}")" \
      "$(output_json_array "${unselected_results[@]}")" \
      "$desired_count" \
      "$installed_desired_count" \
      "$missing_desired_count" \
      "$installed_unselected_count" \
      "$exit_status"
    return "$exit_status"
  fi

  reporting_print_status_summary \
    "$desired_count" \
    "$installed_desired_count" \
    "$missing_desired_count" \
    "$installed_unselected_count"

  return "$exit_status"
}
