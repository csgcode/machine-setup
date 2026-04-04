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

  if chezmoi_array_contains "$item" "${current[@]}"; then
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

chezmoi_is_initialized() {
  chezmoi_is_installed && chezmoi source-path >/dev/null 2>&1
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
      mapfile -t next < <(chezmoi_append_unique "$base_target" "${resolved[@]}")
      resolved=("${next[@]}")
    fi
  fi

  for target in "${targets[@]}"; do
    [[ -z "$target" ]] && continue
    mapfile -t next < <(chezmoi_append_unique "$target" "${resolved[@]}")
    resolved=("${next[@]}")
  done

  printf '%s\n' "${resolved[@]}"
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
    mapfile -t resolved < <(chezmoi_resolve_targets "${targets[@]}")
  else
    mapfile -t resolved < <(chezmoi_resolve_targets --no-base -- "${targets[@]}")
  fi

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No chezmoi targets selected for apply"
    return 0
  fi

  chezmoi_ensure_ready || return 1

  local target
  for target in "${resolved[@]}"; do
    cmd+=("--include=tags:$target")
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
    mapfile -t resolved < <(chezmoi_resolve_targets "${targets[@]}")
  else
    mapfile -t resolved < <(chezmoi_resolve_targets --no-base -- "${targets[@]}")
  fi

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No chezmoi targets selected for diff"
    return 0
  fi

  chezmoi_ensure_ready || return 1

  local target
  for target in "${resolved[@]}"; do
    cmd+=("--include=tags:$target")
  done

  if [[ "${SETUP_DRY_RUN:-0}" -eq 1 ]]; then
    chezmoi_run_command "${cmd[@]}"
    return 0
  fi

  "${cmd[@]}"
}
