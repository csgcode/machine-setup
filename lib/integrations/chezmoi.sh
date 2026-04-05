#!/usr/bin/env bash

chezmoi_array_contains() {
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

chezmoi_append_unique() {
  local item="$1"
  shift
  local current=("$@")

  if [[ "${#current[@]}" -gt 0 ]] && chezmoi_array_contains "$item" "${current[@]}"; then
    printf '%s\n' "${current[@]}"
    return 0
  fi

  current+=("$item")
  printf '%s\n' "${current[@]}"
}

chezmoi_format_command() {
  local args=()
  local arg quoted

  for arg in "$@"; do
    printf -v quoted '%q' "$arg"
    args+=("$quoted")
  done

  printf '%s\n' "${args[*]}"
}

chezmoi_run_command() {
  local cmd
  cmd="$(chezmoi_format_command "$@")"
  run_eval "$cmd"
}

chezmoi_is_installed() {
  command_exists chezmoi
}

chezmoi_source_path() {
  chezmoi_is_installed || return 1
  chezmoi source-path 2>/dev/null
}

chezmoi_is_initialized() {
  local source_path=""

  source_path="$(chezmoi_source_path)" || return 1
  [[ -d "$source_path" ]]
}

chezmoi_install() {
  if chezmoi_is_installed; then
    log_info "chezmoi already installed"
    return 0
  fi

  if ! command_exists brew; then
    log_error "Cannot bootstrap chezmoi because Homebrew is not installed"
    return 1
  fi

  log_info "Installing chezmoi"
  brew_install_formula chezmoi
}

chezmoi_resolve_repo_url() {
  local repo_url=""

  repo_url="$(state_get_config_value "chezmoi.repo_url" | head -n1)"
  if [[ -n "$repo_url" ]]; then
    printf '%s\n' "$repo_url"
    return 0
  fi

  if [[ "${SETUP_YES:-0}" -eq 1 || ! -t 0 ]]; then
    log_error "Missing chezmoi.repo_url configuration. Set CHEZMOI_REPO_URL or configure $(state_config_path)"
    return 1
  fi

  read -r -p "Chezmoi repository URL: " repo_url
  if [[ -z "$repo_url" ]]; then
    log_error "Chezmoi repository URL cannot be empty"
    return 1
  fi

  printf '%s\n' "$repo_url"
}

chezmoi_init() {
  local repo_url="${1:-}"

  if chezmoi_is_initialized; then
    log_info "chezmoi already initialized"
    return 0
  fi

  if [[ -z "$repo_url" ]]; then
    repo_url="$(chezmoi_resolve_repo_url)" || return 1
  fi

  log_info "Initializing chezmoi"
  chezmoi_run_command chezmoi init --apply=false "$repo_url"

  if [[ "${SETUP_DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi

  if ! chezmoi_is_initialized; then
    log_error "Chezmoi init did not create a usable source directory"
    return 1
  fi
}

chezmoi_ensure_ready() {
  local repo_url="${1:-}"

  chezmoi_install || return 1

  if chezmoi_is_initialized; then
    return 0
  fi

  chezmoi_init "$repo_url"
}

chezmoi_resolve_targets() {
  local include_base=1
  local base_target=""
  local targets=()
  local resolved=()
  local target
  local next=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-base)
        include_base=0
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  targets=("$@")

  if [[ "$include_base" -eq 1 ]]; then
    base_target="$(state_get_config_value "chezmoi.base_target" | head -n1)"
    if [[ -n "$base_target" ]]; then
      if [[ "${#resolved[@]}" -gt 0 ]]; then
        read_lines_into_array next chezmoi_append_unique "$base_target" "${resolved[@]}"
      else
        read_lines_into_array next chezmoi_append_unique "$base_target"
      fi
      if [[ "${#next[@]}" -gt 0 ]]; then
        resolved=("${next[@]}")
      else
        resolved=()
      fi
    fi
  fi

  for target in "${targets[@]}"; do
    [[ -z "$target" ]] && continue
    if [[ "${#resolved[@]}" -gt 0 ]]; then
      read_lines_into_array next chezmoi_append_unique "$target" "${resolved[@]}"
    else
      read_lines_into_array next chezmoi_append_unique "$target"
    fi
    if [[ "${#next[@]}" -gt 0 ]]; then
      resolved=("${next[@]}")
    else
      resolved=()
    fi
  done

  if [[ "${#resolved[@]}" -gt 0 ]]; then
    printf '%s\n' "${resolved[@]}"
  fi
}

chezmoi_apply_targets() {
  local optional=0
  local include_base=1
  local targets=()
  local resolved=()
  local cmd=(chezmoi apply)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --optional)
        optional=1
        shift
        ;;
      --no-base)
        include_base=0
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  targets=("$@")
  if [[ "$include_base" -eq 1 ]]; then
    read_lines_into_array resolved chezmoi_resolve_targets "${targets[@]}"
  else
    read_lines_into_array resolved chezmoi_resolve_targets --no-base -- "${targets[@]}"
  fi

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No chezmoi targets selected for apply"
    return 0
  fi

  chezmoi_ensure_ready || return 1

  local target
  for target in "${resolved[@]}"; do
    cmd+=("$target")
  done

  if chezmoi_run_command "${cmd[@]}"; then
    return 0
  fi

  if [[ "$optional" -eq 1 ]]; then
    log_warn "Optional chezmoi apply failed for targets: ${resolved[*]}"
    return 0
  fi

  log_error "Chezmoi apply failed for targets: ${resolved[*]}"
  return 1
}

chezmoi_target_exists() {
  local target="$1"
  local output=""
  local status=0

  chezmoi_ensure_ready >&2 || return 1

  output="$(chezmoi managed "$target" 2>/dev/null)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    if [[ -n "$output" ]]; then
      return 0
    fi

    return 1
  fi

  if [[ "$status" -eq 1 ]]; then
    return 1
  fi

  return "$status"
}

chezmoi_target_status() {
  local target="$1"
  local output=""
  local status=0

  chezmoi_target_exists "$target"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    if [[ "$status" -eq 1 ]]; then
      printf 'unavailable\nNo managed chezmoi entries for target %s\n' "$target"
      return 0
    fi

    printf 'unavailable\nFailed to inspect chezmoi target %s\n' "$target"
    return 0
  fi

  status=0
  output="$(chezmoi diff "$target" 2>&1)" || status=$?
  if [[ "$status" -eq 0 ]]; then
    printf 'clean\n'
    return 0
  fi

  if [[ "$status" -eq 1 ]]; then
    printf 'drifted\n%s\n' "$output"
    return 0
  fi

  printf 'unavailable\n%s\n' "${output:-Chezmoi diff failed for target $target}"
  return 0
}

chezmoi_diff_targets() {
  local include_base=1
  local targets=()
  local resolved=()
  local cmd=(chezmoi diff)

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-base)
        include_base=0
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  targets=("$@")
  if [[ "$include_base" -eq 1 ]]; then
    read_lines_into_array resolved chezmoi_resolve_targets "${targets[@]}"
  else
    read_lines_into_array resolved chezmoi_resolve_targets --no-base -- "${targets[@]}"
  fi

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No chezmoi targets selected for diff"
    return 0
  fi

  chezmoi_ensure_ready || return 1

  local target
  for target in "${resolved[@]}"; do
    cmd+=("$target")
  done

  if [[ "${SETUP_DRY_RUN:-0}" -eq 1 ]]; then
    chezmoi_run_command "${cmd[@]}"
    return 0
  fi

  "${cmd[@]}"
}
