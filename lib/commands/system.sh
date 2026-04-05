#!/usr/bin/env bash

cmd_list() {
  if output_is_json; then
    package_ruby_manifest '
      data=YAML.load_file(ARGV[0])
      payload={
        "packages" => data.fetch("packages", []).sort_by{|p| p["id"]}.map do |p|
          {
            "id" => p["id"],
            "group" => p["group"],
            "installer_kind" => p.dig("installer", "kind")
          }
        end
      }
      puts JSON.pretty_generate(payload)
    '
    return 0
  fi

  printf 'ID\tGROUP\tMANAGER\n'
  package_summary_table
}

cmd_doctor() {
  local required=(brew git curl ruby)
  local missing=0
  local missing_count=0
  local results=()
  local cmd=""
  local state=""

  if ! output_is_json; then
    log_info "Running doctor checks"
  fi

  for cmd in "${required[@]}"; do
    if command_exists "$cmd"; then
      state="ok"
      if ! output_is_json; then
        printf '  [ok] %s\n' "$cmd"
      fi
    else
      state="missing"
      if ! output_is_json; then
        printf '  [missing] %s\n' "$cmd"
      fi
      missing=1
      missing_count=$((missing_count + 1))
    fi

    results+=("{\"command\":$(output_json_string "$cmd"),\"status\":$(output_json_string "$state")}")
  done

  if output_is_json; then
    printf '{\n'
    printf '  "checks": %s,\n' "$(output_json_array "${results[@]}")"
    printf '  "summary": {"missing": %s, "ok": %s}\n' \
      "$missing_count" \
      "$(( ${#required[@]} - missing_count ))"
    printf '}\n'
    if [[ "$missing" -eq 1 ]]; then
      return 1
    fi

    return 0
  fi

  if [[ "$missing" -eq 1 ]]; then
    log_warn "Doctor found missing required commands"
    return 1
  fi

  log_info "Doctor checks passed"
}

cmd_bootstrap() {
  local was_installed=0
  local was_initialized=0
  local repo_url=""
  local actions=()
  local now_installed=0
  local now_initialized=0

  chezmoi_is_installed && was_installed=1
  chezmoi_is_initialized && was_initialized=1

  if [[ "$was_installed" -eq 0 ]]; then
    actions+=("\"install\"")
  fi

  if [[ "$was_initialized" -eq 0 ]]; then
    repo_url="$(chezmoi_resolve_repo_url)" || return 1
    actions+=("\"init\"")
  fi

  if output_is_json; then
    chezmoi_ensure_ready "$repo_url" >/dev/null || return 1
  else
    chezmoi_ensure_ready "$repo_url" || return 1
  fi

  chezmoi_is_installed && now_installed=1
  chezmoi_is_initialized && now_initialized=1

  if output_is_json; then
    printf '{\n'
    printf '  "ready": %s,\n' "$(output_json_bool "$(( now_installed == 1 && now_initialized == 1 ? 1 : 0 ))")"
    printf '  "dry_run": %s,\n' "$(output_json_bool "$SETUP_DRY_RUN")"
    printf '  "before": {"installed": %s, "initialized": %s},\n' \
      "$(output_json_bool "$was_installed")" \
      "$(output_json_bool "$was_initialized")"
    printf '  "after": {"installed": %s, "initialized": %s},\n' \
      "$(output_json_bool "$now_installed")" \
      "$(output_json_bool "$now_initialized")"
    printf '  "planned_actions": %s\n' "$(output_json_array "${actions[@]}")"
    printf '}\n'
    return 0
  fi

  if [[ "${#actions[@]}" -eq 0 ]]; then
    printf 'Chezmoi is already ready.\n'
    return 0
  fi

  printf 'Chezmoi bootstrap complete.\n'
  printf 'Planned or completed actions: %s\n' "${actions[*]//\"/}"
}
