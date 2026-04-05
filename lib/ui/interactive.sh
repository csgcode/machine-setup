#!/usr/bin/env bash

INTERACTIVE_ACTION=""
INTERACTIVE_SELECTION_MODE=""
INTERACTIVE_SELECTED_PACKAGES=()
INTERACTIVE_SELECTED_TAGS=()
INTERACTIVE_SELECTED_PROFILES=()

interactive_reset_state() {
  INTERACTIVE_ACTION=""
  INTERACTIVE_SELECTION_MODE=""
  INTERACTIVE_SELECTED_PACKAGES=()
  INTERACTIVE_SELECTED_TAGS=()
  INTERACTIVE_SELECTED_PROFILES=()
}

interactive_prompt() {
  local prompt="$1"
  local response=""

  printf '%s' "$prompt" >&2
  if ! IFS= read -r response; then
    log_warn "Interactive input cancelled"
    return 1
  fi

  printf '%s\n' "$response"
}

interactive_choose_action() {
  local choice=""

  printf 'Select action:\n'
  printf '  1) Install selected software\n'
  printf '  2) Check selected software\n'
  printf '  3) Apply config for selected software\n'
  printf '  4) Exit\n'

  choice="$(interactive_prompt "Choose an option [1-4]: ")" || return 1

  case "$choice" in
    1) INTERACTIVE_ACTION="install" ;;
    2) INTERACTIVE_ACTION="check" ;;
    3) INTERACTIVE_ACTION="apply-config" ;;
    4) INTERACTIVE_ACTION="exit" ;;
    *)
      log_error "Invalid action selection"
      return 1
      ;;
  esac
}

interactive_choose_selection_mode() {
  local choice=""

  printf 'Select how to choose software:\n'
  printf '  1) Individual packages\n'
  printf '  2) Tags\n'
  printf '  3) Profiles\n'
  printf '  4) Cancel\n'

  choice="$(interactive_prompt "Choose an option [1-4]: ")" || return 1

  case "$choice" in
    1) INTERACTIVE_SELECTION_MODE="package" ;;
    2) INTERACTIVE_SELECTION_MODE="tag" ;;
    3) INTERACTIVE_SELECTION_MODE="profile" ;;
    4) INTERACTIVE_SELECTION_MODE="cancel" ;;
    *)
      log_error "Invalid selection mode"
      return 1
      ;;
  esac
}

interactive_select_values() {
  local kind="$1"
  shift
  local values=("$@")
  local input=""
  local selected=()
  local tokens=()
  local token=""
  local index=""
  local value=""

  if [[ "${#values[@]}" -eq 0 ]]; then
    log_warn "No $kind options available"
    return 1
  fi

  printf 'Available %ss:\n' "$kind"
  local i=1
  for value in "${values[@]}"; do
    printf '  %s) %s\n' "$i" "$value"
    i=$((i + 1))
  done

  input="$(interactive_prompt "Enter comma-separated numbers: ")" || return 1
  IFS=',' read -r -a tokens <<< "$input"

  for token in "${tokens[@]}"; do
    index="${token// /}"
    if [[ -z "$index" ]]; then
      continue
    fi
    if ! [[ "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > ${#values[@]} )); then
      log_error "Invalid $kind selection: $token"
      return 1
    fi
    value="${values[index-1]}"
    if ! selection_array_contains "$value" "${selected[@]+"${selected[@]}"}"; then
      selected+=("$value")
    fi
  done

  if [[ "${#selected[@]}" -eq 0 ]]; then
    log_error "No $kind values selected"
    return 1
  fi

  if [[ "$kind" == "package" ]]; then
    INTERACTIVE_SELECTED_PACKAGES=("${selected[@]}")
    INTERACTIVE_SELECTED_TAGS=()
    INTERACTIVE_SELECTED_PROFILES=()
  elif [[ "$kind" == "tag" ]]; then
    INTERACTIVE_SELECTED_PACKAGES=()
    INTERACTIVE_SELECTED_TAGS=("${selected[@]}")
    INTERACTIVE_SELECTED_PROFILES=()
  else
    INTERACTIVE_SELECTED_PACKAGES=()
    INTERACTIVE_SELECTED_TAGS=()
    INTERACTIVE_SELECTED_PROFILES=("${selected[@]}")
  fi
}

interactive_select_packages() {
  local packages=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    packages+=("$pkg")
  done < <(list_all_packages)

  interactive_select_values "package" "${packages[@]}"
}

interactive_select_tags() {
  local tags=()
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    tags+=("$tag")
  done < <(list_all_tags)

  interactive_select_values "tag" "${tags[@]}"
}

interactive_select_profiles() {
  local profiles=()
  local profile=""
  while IFS= read -r profile; do
    [[ -z "$profile" ]] && continue
    profiles+=("$profile")
  done < <(list_all_profiles)

  interactive_select_values "profile" "${profiles[@]}"
}

interactive_selection_args() {
  local pkg
  local tag
  local profile

  for pkg in "${INTERACTIVE_SELECTED_PACKAGES[@]+"${INTERACTIVE_SELECTED_PACKAGES[@]}"}"; do
    printf '%s\n%s\n' "--package" "$pkg"
  done

  for tag in "${INTERACTIVE_SELECTED_TAGS[@]+"${INTERACTIVE_SELECTED_TAGS[@]}"}"; do
    printf '%s\n%s\n' "--tag" "$tag"
  done

  for profile in "${INTERACTIVE_SELECTED_PROFILES[@]+"${INTERACTIVE_SELECTED_PROFILES[@]}"}"; do
    printf '%s\n%s\n' "--profile" "$profile"
  done
}

interactive_show_resolved_packages() {
  local selection_args=()
  local resolved=()
  local pkg=""

  read_lines_into_array selection_args interactive_selection_args
  read_lines_into_array resolved selection_resolve_inputs "${selection_args[@]}" || return 1

  if [[ "${#resolved[@]}" -eq 0 ]]; then
    log_warn "No packages resolved from the current selection"
    return 1
  fi

  printf 'Resolved packages:\n'
  for pkg in "${resolved[@]}"; do
    printf '  - %s\n' "$pkg"
  done
}

interactive_confirm_execution() {
  local response=""
  response="$(interactive_prompt "Proceed? [y/N]: ")" || return 1
  [[ "$response" =~ ^[Yy]$ ]]
}

interactive_maybe_save_selection() {
  local response=""

  response="$(interactive_prompt "Save this selection to local machine state? [y/N]: ")" || return 1
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    return 0
  fi

  local args=()
  local pkg
  local tag
  local profile

  for pkg in "${INTERACTIVE_SELECTED_PACKAGES[@]+"${INTERACTIVE_SELECTED_PACKAGES[@]}"}"; do
    args+=("--include-package" "$pkg")
  done
  for tag in "${INTERACTIVE_SELECTED_TAGS[@]+"${INTERACTIVE_SELECTED_TAGS[@]}"}"; do
    args+=("--include-tag" "$tag")
  done
  for profile in "${INTERACTIVE_SELECTED_PROFILES[@]+"${INTERACTIVE_SELECTED_PROFILES[@]}"}"; do
    args+=("--profile" "$profile")
  done

  state_write_machine_state "${args[@]}"
  log_info "Saved selection to $(state_state_path)"
}

interactive_apply_selection_to_cli() {
  CLI_GROUP=""
  CLI_PACKAGES=("${INTERACTIVE_SELECTED_PACKAGES[@]+"${INTERACTIVE_SELECTED_PACKAGES[@]}"}")
  CLI_TAGS=("${INTERACTIVE_SELECTED_TAGS[@]+"${INTERACTIVE_SELECTED_TAGS[@]}"}")
  CLI_PROFILES=("${INTERACTIVE_SELECTED_PROFILES[@]+"${INTERACTIVE_SELECTED_PROFILES[@]}"}")
}

cmd_interactive() {
  interactive_reset_state
  interactive_choose_action || return 1

  if [[ "$INTERACTIVE_ACTION" == "exit" ]]; then
    return 0
  fi

  interactive_choose_selection_mode || return 1
  if [[ "$INTERACTIVE_SELECTION_MODE" == "cancel" ]]; then
    log_warn "Interactive flow cancelled"
    return 0
  fi

  case "$INTERACTIVE_SELECTION_MODE" in
    package)
      interactive_select_packages || return 1
      ;;
    tag)
      interactive_select_tags || return 1
      ;;
    profile)
      interactive_select_profiles || return 1
      ;;
  esac

  interactive_show_resolved_packages || return 1

  if ! interactive_confirm_execution; then
    log_warn "Aborted before execution"
    return 0
  fi

  interactive_apply_selection_to_cli

  case "$INTERACTIVE_ACTION" in
    install)
      cmd_install || return 1
      interactive_maybe_save_selection || return 1
      ;;
    check)
      cmd_check || return $?
      ;;
    apply-config)
      cmd_apply_config || return 1
      interactive_maybe_save_selection || return 1
      ;;
  esac
}
