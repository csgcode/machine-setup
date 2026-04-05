#!/usr/bin/env bash

if [[ -z "${SETUP_VERBOSE:-}" ]]; then
  SETUP_VERBOSE=0
fi

if [[ -z "${SETUP_SUPPRESS_LOGS:-}" ]]; then
  SETUP_SUPPRESS_LOGS=0
fi

log_info() {
  if [[ "${SETUP_SUPPRESS_LOGS:-0}" -eq 1 ]]; then
    return 0
  fi
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  if [[ "${SETUP_SUPPRESS_LOGS:-0}" -eq 1 ]]; then
    return 0
  fi
  printf '[WARN] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

log_debug() {
  if [[ "${SETUP_SUPPRESS_LOGS:-0}" -eq 1 ]]; then
    return 0
  fi
  if [[ "$SETUP_VERBOSE" -eq 1 ]]; then
    printf '[DEBUG] %s\n' "$*"
  fi
}
