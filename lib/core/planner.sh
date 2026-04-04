#!/usr/bin/env bash

planner_emit_package_action() {
  local pkg="$1"
  local kind target

  kind="$(package_installer_kind "$pkg" | head -n1)"
  target="$(package_install_target "$pkg" | head -n1)"

  printf 'package\t%s\t%s\t%s\n' "$pkg" "$kind" "$target"
}

planner_emit_config_action() {
  local pkg="$1"
  local strategy target optional

  strategy="$(package_field "$pkg" "config.strategy" | head -n1)"
  target="$(package_field "$pkg" "config.target" | head -n1)"
  optional="$(package_config_optional "$pkg" | head -n1)"

  if [[ -z "$strategy" || -z "$target" ]]; then
    return 0
  fi

  printf 'config\t%s\t%s\t%s\t%s\n' "$pkg" "$strategy" "$target" "${optional:-false}"
}

planner_emit_manual_actions() {
  local pkg="$1"
  local step

  while IFS= read -r step; do
    [[ -z "$step" ]] && continue
    printf 'manual_step\t%s\t%s\n' "$pkg" "$step"
  done < <(package_field "$pkg" "manual_steps")
}

planner_emit_actions_for_package() {
  local pkg="$1"
  planner_emit_package_action "$pkg"
  planner_emit_config_action "$pkg"
  planner_emit_manual_actions "$pkg"
}

planner_build_install_plan_from_resolved_packages() {
  local pkg
  for pkg in "$@"; do
    [[ -z "$pkg" ]] && continue
    planner_emit_actions_for_package "$pkg"
  done
}

planner_build_install_plan_from_packages() {
  local resolved=()
  read_lines_into_array resolved selection_resolve_packages "$@" || return 1
  if [[ "${#resolved[@]}" -eq 0 ]]; then
    return 0
  fi
  planner_build_install_plan_from_resolved_packages "${resolved[@]}"
}

planner_build_install_plan_from_tags() {
  local resolved=()
  read_lines_into_array resolved selection_resolve_tags "$@" || return 1
  if [[ "${#resolved[@]}" -eq 0 ]]; then
    return 0
  fi
  planner_build_install_plan_from_resolved_packages "${resolved[@]}"
}

planner_build_install_plan_from_inputs() {
  local resolved=()
  read_lines_into_array resolved selection_resolve_inputs "$@" || return 1
  if [[ "${#resolved[@]}" -eq 0 ]]; then
    return 0
  fi
  planner_build_install_plan_from_resolved_packages "${resolved[@]}"
}
