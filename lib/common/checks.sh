#!/usr/bin/env bash

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_cmd() {
  local cmd="$1"
  if ! command_exists "$cmd"; then
    echo "Missing required command: $cmd" >&2
    return 1
  fi
}

run_eval() {
  local cmd="$1"
  if [[ "${SETUP_DRY_RUN:-0}" -eq 1 ]]; then
    printf '[DRY-RUN] %s\n' "$cmd"
    return 0
  fi
  eval "$cmd"
}

read_lines_into_array() {
  local target_var="$1"
  shift
  local output=""
  local status=0
  local line=""

  eval "$target_var=()"

  output="$("$@")"
  status=$?

  if [[ -z "$output" ]]; then
    return "$status"
  fi

  while IFS= read -r line; do
    eval "$target_var+=(\"\$line\")"
  done <<< "$output"

  return "$status"
}
