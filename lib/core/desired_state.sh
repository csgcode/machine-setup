#!/usr/bin/env bash

desired_state_selection_args_from_profile() {
  local profile_id="$1"
  local pkg=""
  local tag=""

  if [[ -z "$profile_id" ]]; then
    return 0
  fi

  if ! profile_exists "$profile_id"; then
    log_error "Unknown profile: $profile_id"
    return 1
  fi

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf '%s\n%s\n' "--package" "$pkg"
  done < <(profile_packages "$profile_id")

  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    printf '%s\n%s\n' "--tag" "$tag"
  done < <(profile_tags "$profile_id")
}

desired_state_direct_selection_args() {
  local profile_id=""
  local profile_args=()
  local pkg=""
  local tag=""

  profile_id="$(state_get_selected_profile | head -n1)"
  read_lines_into_array profile_args desired_state_selection_args_from_profile "$profile_id" || return 1
  if [[ "${#profile_args[@]}" -gt 0 ]]; then
    printf '%s\n' "${profile_args[@]}"
  fi

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    printf '%s\n%s\n' "--package" "$pkg"
  done < <(state_get_package_includes)

  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    printf '%s\n%s\n' "--tag" "$tag"
  done < <(state_get_tag_includes)
}

desired_state_excluded_direct_packages() {
  local excluded=()
  local pkg=""
  local tag=""
  local tagged_pkg=""

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if ! selection_array_contains "$pkg" "${excluded[@]+"${excluded[@]}"}"; then
      excluded+=("$pkg")
    fi
  done < <(state_get_package_excludes)

  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    if ! tag_exists "$tag"; then
      log_error "Unknown excluded tag: $tag"
      return 1
    fi
    while IFS= read -r tagged_pkg; do
      [[ -z "$tagged_pkg" ]] && continue
      if ! selection_array_contains "$tagged_pkg" "${excluded[@]+"${excluded[@]}"}"; then
        excluded+=("$tagged_pkg")
      fi
    done < <(tag_packages "$tag")
  done < <(state_get_tag_excludes)

  if [[ "${#excluded[@]}" -gt 0 ]]; then
    printf '%s\n' "${excluded[@]}"
  fi
}

desired_state_resolve_packages() {
  local direct_selection_args=()
  local direct_packages=()
  local excluded_packages=()
  local desired_direct_packages=()
  local pkg=""

  read_lines_into_array direct_selection_args desired_state_direct_selection_args || return 1
  if [[ "${#direct_selection_args[@]}" -gt 0 ]]; then
    read_lines_into_array direct_packages selection_resolve_direct_inputs "${direct_selection_args[@]}" || return 1
  fi
  read_lines_into_array excluded_packages desired_state_excluded_direct_packages || return 1

  for pkg in "${direct_packages[@]+"${direct_packages[@]}"}"; do
    [[ -z "$pkg" ]] && continue
    if selection_array_contains "$pkg" "${excluded_packages[@]+"${excluded_packages[@]}"}"; then
      continue
    fi
    if ! selection_array_contains "$pkg" "${desired_direct_packages[@]+"${desired_direct_packages[@]}"}"; then
      desired_direct_packages+=("$pkg")
    fi
  done

  if [[ "${#desired_direct_packages[@]}" -eq 0 ]]; then
    return 0
  fi

  selection_resolve_packages "${desired_direct_packages[@]}"
}
