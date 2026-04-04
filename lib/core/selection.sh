#!/usr/bin/env bash

SELECTION_RESULT=()
SELECTION_DONE=()
SELECTION_STACK=()

selection_reset_state() {
  SELECTION_RESULT=()
  SELECTION_DONE=()
  SELECTION_STACK=()
}

selection_array_contains() {
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

selection_done_contains() {
  local needle="$1"
  local item

  for item in "${SELECTION_DONE[@]+"${SELECTION_DONE[@]}"}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

selection_stack_contains() {
  local needle="$1"
  local item

  for item in "${SELECTION_STACK[@]+"${SELECTION_STACK[@]}"}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

selection_push_stack() {
  local pkg="$1"
  SELECTION_STACK+=("$pkg")
}

selection_pop_stack() {
  local last_index
  last_index=$((${#SELECTION_STACK[@]} - 1))
  unset 'SELECTION_STACK[last_index]'
}

selection_format_cycle() {
  local pkg="$1"
  local started=0
  local path=()
  local item

  for item in "${SELECTION_STACK[@]}"; do
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

selection_visit_package() {
  local pkg="$1"

  if selection_done_contains "$pkg"; then
    return 0
  fi

  if selection_stack_contains "$pkg"; then
    log_error "Circular dependency detected: $(selection_format_cycle "$pkg")"
    return 1
  fi

  if ! package_exists "$pkg"; then
    log_error "Unknown package: $pkg"
    return 1
  fi

  selection_push_stack "$pkg"

  local dep
  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    selection_visit_package "$dep" || {
      selection_pop_stack
      return 1
    }
  done < <(package_dependencies "$pkg")

  selection_pop_stack
  SELECTION_DONE+=("$pkg")
  SELECTION_RESULT+=("$pkg")
}

selection_resolve_packages() {
  validate_manifest_schema || return 1
  selection_reset_state

  local pkg
  for pkg in "$@"; do
    [[ -z "$pkg" ]] && continue
    selection_visit_package "$pkg" || return 1
  done

  if [[ "${#SELECTION_RESULT[@]}" -gt 0 ]]; then
    printf '%s\n' "${SELECTION_RESULT[@]}"
  fi
}

selection_resolve_tags() {
  validate_manifest_schema || return 1
  selection_reset_state

  local tag
  local pkg
  for tag in "$@"; do
    [[ -z "$tag" ]] && continue
    if ! tag_exists "$tag"; then
      log_error "Unknown tag: $tag"
      return 1
    fi

    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      selection_visit_package "$pkg" || return 1
    done < <(tag_packages "$tag")
  done

  if [[ "${#SELECTION_RESULT[@]}" -gt 0 ]]; then
    printf '%s\n' "${SELECTION_RESULT[@]}"
  fi
}

selection_resolve_inputs() {
  validate_manifest_schema || return 1
  selection_reset_state

  local mode=""
  local value=""

  while [[ $# -gt 0 ]]; do
    mode="$1"
    value="${2:-}"

    case "$mode" in
      --package)
        if [[ -z "$value" ]]; then
          log_error "Missing value for --package"
          return 1
        fi
        selection_visit_package "$value" || return 1
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
        local pkg
        while IFS= read -r pkg; do
          [[ -z "$pkg" ]] && continue
          selection_visit_package "$pkg" || return 1
        done < <(tag_packages "$value")
        shift 2
        ;;
      *)
        log_error "Unsupported selection input: $mode"
        return 1
        ;;
    esac
  done

  if [[ "${#SELECTION_RESULT[@]}" -gt 0 ]]; then
    printf '%s\n' "${SELECTION_RESULT[@]}"
  fi
}
