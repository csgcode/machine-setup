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

validate_collect_ignore_manifest() {
  IGNORE_FILE_PATH="$ROOT_DIR/manifests/collect-ignore.yaml" ruby -ryaml -e '
    path=ENV["IGNORE_FILE_PATH"]
    exit 0 unless File.exist?(path)

    data=YAML.load_file(path) || {}
    errors=[]
    errors << "collect-ignore.yaml: schema_version must be 1" unless data["schema_version"] == 1

    ignore=data["ignore"] || {}
    %w[package_ids brew_formula brew_cask npm_global].each do |key|
      value=ignore[key]
      next if value.nil? || value.is_a?(Array)

      errors << "collect-ignore.yaml: ignore.#{key} must be an array"
    end

    unless errors.empty?
      warn errors.join("\n")
      exit 1
    end
  '
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
run_step "Validating collect ignore manifest" validate_collect_ignore_manifest

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
