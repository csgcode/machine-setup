#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  CHEZMOI_LOG="$BATS_TEST_TMPDIR/chezmoi.log"
  CHEZMOI_INSTALLED_FILE="$BATS_TEST_TMPDIR/chezmoi-installed"
  CHEZMOI_INITIALIZED_FILE="$BATS_TEST_TMPDIR/chezmoi-initialized"
  CHEZMOI_TEMPLATE="$BATS_TEST_TMPDIR/chezmoi-template"

  mkdir -p "$TEST_HOME" "$TEST_BIN"
  : > "$CHEZMOI_LOG"

  cat > "$CHEZMOI_TEMPLATE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${CHEZMOI_LOG:?}"
printf 'chezmoi %s\n' "$*" >> "$log_file"

case "${1:-}" in
  source-path)
    if [[ -f "${CHEZMOI_INITIALIZED_FILE:?}" ]]; then
      printf '%s\n' "${CHEZMOI_SOURCE_PATH:-$HOME/.local/share/chezmoi}"
      exit 0
    fi
    exit 1
    ;;
  init)
    touch "${CHEZMOI_INITIALIZED_FILE:?}"
    exit 0
    ;;
  apply)
    if [[ "${CHEZMOI_FAIL_APPLY:-0}" -eq 1 ]]; then
      exit 1
    fi
    exit 0
    ;;
  diff)
    printf 'diff %s\n' "$*" 
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$CHEZMOI_TEMPLATE"

  cat > "$TEST_BIN/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'brew %s\n' "$*" >> "${CHEZMOI_LOG:?}"

if [[ "${1:-}" == "list" && "${2:-}" == "--formula" && "${3:-}" == "chezmoi" ]]; then
  [[ -f "${CHEZMOI_INSTALLED_FILE:?}" ]]
  exit $?
fi

if [[ "${1:-}" == "install" && "${2:-}" == "chezmoi" ]]; then
  cp "${CHEZMOI_TEMPLATE:?}" "${TEST_BIN:?}/chezmoi"
  chmod +x "${TEST_BIN:?}/chezmoi"
  touch "${CHEZMOI_INSTALLED_FILE:?}"
  exit 0
fi

exit 0
EOF
  chmod +x "$TEST_BIN/brew"
}

@test "chezmoi ensure ready bootstraps and initializes from repo url" {
  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INSTALLED_FILE="'"$CHEZMOI_INSTALLED_FILE"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    export CHEZMOI_TEMPLATE="'"$CHEZMOI_TEMPLATE"'"
    export TEST_BIN="'"$TEST_BIN"'"
    export CHEZMOI_REPO_URL="https://example.com/dotfiles.git"
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_ensure_ready
    printf -- "---\n"
    cat "'"$CHEZMOI_LOG"'"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing chezmoi"* ]]
  [[ "$output" == *"Initializing chezmoi"* ]]
  [[ "$output" == *$'---\nbrew list --formula chezmoi\nbrew install chezmoi\nchezmoi source-path\nchezmoi source-path\nchezmoi init --apply=false https://example.com/dotfiles.git'* ]]
}

@test "chezmoi ensure ready fails cleanly without repo url in non-interactive mode" {
  cp "$CHEZMOI_TEMPLATE" "$TEST_BIN/chezmoi"
  chmod +x "$TEST_BIN/chezmoi"

  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export SETUP_YES=1
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_ensure_ready
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing chezmoi.repo_url configuration"* ]]
}

@test "chezmoi apply includes configured base target once" {
  cp "$CHEZMOI_TEMPLATE" "$TEST_BIN/chezmoi"
  chmod +x "$TEST_BIN/chezmoi"
  touch "$CHEZMOI_INITIALIZED_FILE"

  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export MACHINE_SETUP_CONFIG_PATH="'"$BATS_TEST_TMPDIR"'/config.yaml"
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    cat > "$MACHINE_SETUP_CONFIG_PATH" <<'"'"'EOF'"'"'
chezmoi:
  base_target: shell-base
EOF
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_apply_targets shell-base alpha
    printf -- "---\n"
    tail -n 1 "'"$CHEZMOI_LOG"'"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *$'---\nchezmoi apply shell-base alpha'* ]]
}

@test "chezmoi optional apply warns and succeeds when target apply fails" {
  cp "$CHEZMOI_TEMPLATE" "$TEST_BIN/chezmoi"
  chmod +x "$TEST_BIN/chezmoi"
  touch "$CHEZMOI_INITIALIZED_FILE"

  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    export CHEZMOI_FAIL_APPLY=1
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_apply_targets --optional alpha
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Optional chezmoi apply failed for targets: alpha"* ]]
}

@test "chezmoi diff returns target-scoped diff output" {
  cp "$CHEZMOI_TEMPLATE" "$TEST_BIN/chezmoi"
  chmod +x "$TEST_BIN/chezmoi"
  touch "$CHEZMOI_INITIALIZED_FILE"

  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export MACHINE_SETUP_CONFIG_PATH="'"$BATS_TEST_TMPDIR"'/config.yaml"
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    cat > "$MACHINE_SETUP_CONFIG_PATH" <<'"'"'EOF'"'"'
chezmoi:
  base_target: shell-base
EOF
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_diff_targets alpha
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"diff diff shell-base alpha"* ]]
}

@test "chezmoi dry-run shows bootstrap init and apply commands without mutation" {
  run bash -c '
    export HOME="'"$TEST_HOME"'"
    export PATH="'"$TEST_BIN"':/usr/bin:/bin"
    export SETUP_DRY_RUN=1
    export MACHINE_SETUP_CONFIG_PATH="'"$BATS_TEST_TMPDIR"'/config.yaml"
    export CHEZMOI_REPO_URL="https://example.com/dotfiles.git"
    export CHEZMOI_LOG="'"$CHEZMOI_LOG"'"
    export CHEZMOI_INSTALLED_FILE="'"$CHEZMOI_INSTALLED_FILE"'"
    export CHEZMOI_INITIALIZED_FILE="'"$CHEZMOI_INITIALIZED_FILE"'"
    export CHEZMOI_TEMPLATE="'"$CHEZMOI_TEMPLATE"'"
    export TEST_BIN="'"$TEST_BIN"'"
    cat > "$MACHINE_SETUP_CONFIG_PATH" <<'"'"'EOF'"'"'
chezmoi:
  base_target: shell-base
EOF
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/installers/brew.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    source "'"$REPO_ROOT"'/lib/integrations/chezmoi.sh"
    chezmoi_apply_targets alpha
    [[ ! -f "'"$CHEZMOI_INSTALLED_FILE"'" ]]
    [[ ! -f "'"$CHEZMOI_INITIALIZED_FILE"'" ]]
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY-RUN] brew list --formula 'chezmoi' >/dev/null 2>&1 || brew install 'chezmoi'"* ]]
  [[ "$output" == *"[DRY-RUN] chezmoi init --apply=false https://example.com/dotfiles.git"* ]]
  [[ "$output" == *"[DRY-RUN] chezmoi apply shell-base alpha"* ]]
}

@test "bootstrap command prepares chezmoi from repo url" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    CHEZMOI_LOG="$CHEZMOI_LOG" \
    CHEZMOI_INSTALLED_FILE="$CHEZMOI_INSTALLED_FILE" \
    CHEZMOI_INITIALIZED_FILE="$CHEZMOI_INITIALIZED_FILE" \
    CHEZMOI_TEMPLATE="$CHEZMOI_TEMPLATE" \
    TEST_BIN="$TEST_BIN" \
    CHEZMOI_REPO_URL="https://example.com/dotfiles.git" \
    "$REPO_ROOT/bin/setup" bootstrap

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing chezmoi"* ]]
  [[ "$output" == *"Initializing chezmoi"* ]]
  [[ "$output" == *"Chezmoi bootstrap complete."* ]]
  run cat "$CHEZMOI_LOG"
  [[ "$output" == *$'brew list --formula chezmoi\nbrew install chezmoi\nchezmoi source-path\nchezmoi source-path\nchezmoi init --apply=false https://example.com/dotfiles.git'* ]]
}

@test "bootstrap command fails cleanly without repo url in non-interactive mode" {
  cp "$CHEZMOI_TEMPLATE" "$TEST_BIN/chezmoi"
  chmod +x "$TEST_BIN/chezmoi"

  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    SETUP_YES=1 \
    CHEZMOI_LOG="$CHEZMOI_LOG" \
    CHEZMOI_INITIALIZED_FILE="$CHEZMOI_INITIALIZED_FILE" \
    "$REPO_ROOT/bin/setup" bootstrap

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing chezmoi.repo_url configuration"* ]]
}

@test "bootstrap command dry-run previews install and init without mutation" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    CHEZMOI_LOG="$CHEZMOI_LOG" \
    CHEZMOI_INSTALLED_FILE="$CHEZMOI_INSTALLED_FILE" \
    CHEZMOI_INITIALIZED_FILE="$CHEZMOI_INITIALIZED_FILE" \
    CHEZMOI_TEMPLATE="$CHEZMOI_TEMPLATE" \
    TEST_BIN="$TEST_BIN" \
    CHEZMOI_REPO_URL="https://example.com/dotfiles.git" \
    "$REPO_ROOT/bin/setup" bootstrap --dry-run --format json

  [ "$status" -eq 0 ]
  [[ ! -f "$CHEZMOI_INSTALLED_FILE" ]]
  [[ ! -f "$CHEZMOI_INITIALIZED_FILE" ]]
  run ruby -rjson -e 'data=JSON.parse(ARGF.read); abort unless data["dry_run"] == true; abort unless data["ready"] == false; abort unless data["planned_actions"] == ["install", "init"]' <<<"$output"
  [ "$status" -eq 0 ]
}
