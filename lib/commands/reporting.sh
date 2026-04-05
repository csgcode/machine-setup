#!/usr/bin/env bash

reporting_selection_args_or_error() {
  local selection_args=()

  if [[ -n "$CLI_GROUP" ]]; then
    log_error "--group is only supported by the legacy install compatibility path"
    return 2
  fi

  read_lines_into_array selection_args executor_selection_args
  if [[ "${#selection_args[@]}" -eq 0 ]]; then
    log_error "drift requires --package or --tag"
    return 2
  fi

  printf '%s\n' "${selection_args[@]}"
}

reporting_resolve_requested_packages() {
  local resolved=()
  local mode=""
  local value=""
  local pkg=""

  validate_manifest_schema || return 1

  while [[ $# -gt 0 ]]; do
    mode="$1"
    value="${2:-}"

    case "$mode" in
      --package)
        if [[ -z "$value" ]]; then
          log_error "Missing value for --package"
          return 1
        fi
        if ! package_exists "$value"; then
          log_error "Unknown package: $value"
          return 1
        fi
        if ! selection_array_contains "$value" "${resolved[@]+"${resolved[@]}"}"; then
          resolved+=("$value")
        fi
        shift 2
        ;;
      --tag)
        if [[ -z "$value" ]]; then
          log_error "Missing value for --tag"
          return 1
        fi
        if ! tag_exists "$value"; then
          log_error "Unknown tag: $value"
          return 1
        fi
        while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          if ! selection_array_contains "$pkg" "${resolved[@]+"${resolved[@]}"}"; then
            resolved+=("$pkg")
          fi
        done < <(tag_packages "$value")
        shift 2
        ;;
      *)
        log_error "Unsupported reporting selection input: $mode"
        return 1
        ;;
    esac
  done

  if [[ "${#resolved[@]}" -gt 0 ]]; then
    printf '%s\n' "${resolved[@]}"
  fi
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

  read_lines_into_array selection_args reporting_selection_args_or_error || return $?
  read_lines_into_array resolved reporting_resolve_requested_packages "${selection_args[@]}" || return 1

  if [[ "${#resolved[@]}" -eq 0 ]]; then
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
        printf '[clean] %s (%s)\n' "$pkg" "$target"
        ;;
      drifted)
        drifted_count=$((drifted_count + 1))
        exit_status=1
        printf '[drifted] %s (%s)\n' "$pkg" "$target"
        if [[ -n "$detail" ]]; then
          printf '%s\n' "$detail"
        fi
        ;;
      unavailable)
        unavailable_count=$((unavailable_count + 1))
        printf '[unavailable] %s (%s): %s\n' "$pkg" "$target" "$detail"
        ;;
      not-applicable)
        not_applicable_count=$((not_applicable_count + 1))
        printf '[not-applicable] %s: %s\n' "$pkg" "$detail"
        ;;
      *)
        log_error "Unknown drift status '$status' for package '$pkg'"
        return 1
        ;;
    esac
  done

  reporting_print_drift_summary \
    "$clean_count" \
    "$drifted_count" \
    "$unavailable_count" \
    "$not_applicable_count"

  return "$exit_status"
}
