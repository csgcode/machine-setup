#!/usr/bin/env bash

if [[ -z "${SETUP_VERBOSE:-}" ]]; then
  SETUP_VERBOSE=0
fi

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

log_debug() {
  if [[ "$SETUP_VERBOSE" -eq 1 ]]; then
    printf '[DEBUG] %s\n' "$*"
  fi
}
