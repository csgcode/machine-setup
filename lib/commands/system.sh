#!/usr/bin/env bash

cmd_list() {
  printf 'ID\tGROUP\tMANAGER\n'
  package_summary_table
}

cmd_doctor() {
  log_info "Running doctor checks"
  local required=(brew git curl ruby)
  local missing=0

  for cmd in "${required[@]}"; do
    if command_exists "$cmd"; then
      printf '  [ok] %s\n' "$cmd"
    else
      printf '  [missing] %s\n' "$cmd"
      missing=1
    fi
  done

  if [[ "$missing" -eq 1 ]]; then
    log_warn "Doctor found missing required commands"
    return 1
  fi

  log_info "Doctor checks passed"
}
