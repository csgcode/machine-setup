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
