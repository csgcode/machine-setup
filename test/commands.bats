#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  TEST_LOG="$BATS_TEST_TMPDIR/backend.log"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_TAGS="$REPO_ROOT/test/fixtures/tags-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
  FIXTURE_PROFILES="$REPO_ROOT/test/fixtures/profiles-basic.yaml"
  TEST_CONFIG="$BATS_TEST_TMPDIR/config.yaml"

  mkdir -p "$TEST_HOME" "$TEST_BIN"
  : > "$TEST_LOG"

  cat > "$TEST_BIN/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'brew %s\n' "$*" >> "${TEST_LOG:?}"
if [[ "${1:-}" == "list" ]]; then
  exit 1
fi
exit 0
EOF
  chmod +x "$TEST_BIN/brew"

  cat > "$TEST_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'chezmoi %s\n' "$*" >> "${TEST_LOG:?}"

case "${1:-}" in
  source-path)
    printf '%s\n' "${CHEZMOI_SOURCE_PATH:-$HOME/.local/share/chezmoi}"
    ;;
  diff)
    printf 'diff %s\n' "$*"
    ;;
esac
EOF
  chmod +x "$TEST_BIN/chezmoi"

  cat > "$TEST_CONFIG" <<'EOF'
chezmoi:
  base_target: shell-base
EOF
}

@test "install --package uses the planner backend for packages config and manual steps" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    MACHINE_SETUP_CONFIG_PATH="$TEST_CONFIG" \
    CHEZMOI_REPO_URL="https://example.com/dotfiles.git" \
    "$REPO_ROOT/bin/setup" install --package alpha

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing: beta"* ]]
  [[ "$output" == *"Installing: alpha"* ]]
  [[ "$output" == *"[manual] alpha: Review alpha after install."* ]]
  run cat "$TEST_LOG"
  [[ "$output" == *$'brew list --formula beta\nbrew install beta\nbrew list --formula alpha\nbrew install alpha'* ]]
  [[ "$output" == *'chezmoi apply shell-base alpha-config'* ]]
}

@test "check --tag reports missing packages from resolved selections" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    "$REPO_ROOT/bin/setup" check --tag test

  [ "$status" -eq 1 ]
  [[ "$output" == *"[missing] beta"* ]]
  [[ "$output" == *"[missing] alpha"* ]]
}

@test "apply-config --package skips package installers and applies config only" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    MACHINE_SETUP_CONFIG_PATH="$TEST_CONFIG" \
    CHEZMOI_REPO_URL="https://example.com/dotfiles.git" \
    "$REPO_ROOT/bin/setup" apply-config --package alpha

  [ "$status" -eq 0 ]
  [[ "$output" == *"[manual] alpha: Review alpha after install."* ]]
  run cat "$TEST_LOG"
  [[ "$output" != *"brew install alpha"* ]]
  [[ "$output" != *"brew install beta"* ]]
  [[ "$output" == *'chezmoi apply shell-base alpha-config'* ]]
}

@test "install --profile resolves through the shared backend" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    MACHINE_SETUP_CONFIG_PATH="$TEST_CONFIG" \
    CHEZMOI_REPO_URL="https://example.com/dotfiles.git" \
    "$REPO_ROOT/bin/setup" install --profile starter

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing: beta"* ]]
  [[ "$output" == *"Installing: alpha"* ]]
  run cat "$TEST_LOG"
  [[ "$output" == *$'brew list --formula beta\nbrew install beta\nbrew list --formula alpha\nbrew install alpha'* ]]
}
