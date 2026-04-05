#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_SHELLCHECK=0

usage() {
  cat <<USAGE
Usage:
  ./scripts/validate.sh [--skip-shellcheck]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-shellcheck)
      SKIP_SHELLCHECK=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run_step() {
  local title="$1"
  shift

  printf '==> %s\n' "$title"
  "$@"
}

validate_manifests() {
  (
    cd "$ROOT_DIR"
    source "$ROOT_DIR/lib/manifest.sh"
    validate_manifest_schema
  )
}

lint_shell() {
  local files=()

  mapfile -t files < <(
    cd "$ROOT_DIR" &&
      rg --files \
        -g 'bin/setup' \
        -g 'lib/**/*.sh' \
        -g 'scripts/**/*.sh' \
        -g 'scripts/*.sh'
  )

  if [[ "${#files[@]}" -eq 0 ]]; then
    return 0
  fi

  (
    cd "$ROOT_DIR"
    shellcheck -x "${files[@]}"
  )
}

run_step "Checking patch cleanliness" git -C "$ROOT_DIR" diff --check
run_step "Validating manifests" validate_manifests

if [[ "$SKIP_SHELLCHECK" -eq 0 ]]; then
  if ! command -v shellcheck >/dev/null 2>&1; then
    printf 'Missing required command: shellcheck\n' >&2
    exit 1
  fi
  run_step "Linting shell scripts" lint_shell
fi

if ! command -v bats >/dev/null 2>&1; then
  printf 'Missing required command: bats\n' >&2
  exit 1
fi

run_step "Running test suite" bats "$ROOT_DIR/test"
