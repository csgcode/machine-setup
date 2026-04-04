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
