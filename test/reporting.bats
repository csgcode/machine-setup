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

  mkdir -p "$TEST_HOME" "$TEST_BIN" "$TEST_HOME/.local/share/chezmoi"
  : > "$TEST_LOG"

  cat > "$TEST_BIN/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'chezmoi %s\n' "$*" >> "${TEST_LOG:?}"

case "${1:-}" in
  source-path)
    printf '%s\n' "${CHEZMOI_SOURCE_PATH:-$HOME/.local/share/chezmoi}"
    exit 0
    ;;
  managed)
    if [[ "${2:-}" == "alpha-config" && "${CHEZMOI_MANAGED_ALPHA:-1}" -eq 1 ]]; then
      printf '%s\n' ".config/alpha"
      exit 0
    fi
    exit 1
    ;;
  diff)
    if [[ "${2:-}" == "alpha-config" ]]; then
      if [[ "${CHEZMOI_DIFF_ALPHA_DRIFT:-0}" -eq 1 ]]; then
        printf '%s\n' 'diff --git a/.config/alpha b/.config/alpha'
        exit 1
      fi
      exit 0
    fi
    exit 0
    ;;
esac

exit 0
EOF
  chmod +x "$TEST_BIN/chezmoi"
}

@test "drift reports clean and not-applicable config states" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    "$REPO_ROOT/bin/setup" drift --tag test

  [ "$status" -eq 0 ]
  [[ "$output" == *"[not-applicable] beta: No config target declared"* ]]
  [[ "$output" == *"[clean] alpha (alpha-config)"* ]]
  [[ "$output" == *"Summary: clean=1 drifted=0 unavailable=0 not-applicable=1"* ]]
}

@test "drift reports config drift and returns non-zero" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    CHEZMOI_DIFF_ALPHA_DRIFT=1 \
    "$REPO_ROOT/bin/setup" drift --package alpha

  [ "$status" -eq 1 ]
  [[ "$output" == *"[drifted] alpha (alpha-config)"* ]]
  [[ "$output" == *"diff --git a/.config/alpha b/.config/alpha"* ]]
  [[ "$output" == *"Summary: clean=0 drifted=1 unavailable=0 not-applicable=0"* ]]
}

@test "drift distinguishes unavailable targets from actual drift" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    CHEZMOI_MANAGED_ALPHA=0 \
    "$REPO_ROOT/bin/setup" drift --package alpha

  [ "$status" -eq 0 ]
  [[ "$output" == *"[unavailable] alpha (alpha-config): No managed chezmoi entries for target alpha-config"* ]]
  [[ "$output" == *"Summary: clean=0 drifted=0 unavailable=1 not-applicable=0"* ]]
}

@test "drift --format json emits structured results" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    TEST_LOG="$TEST_LOG" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    GROUPS_FILE="$FIXTURE_GROUPS" \
    CHEZMOI_DIFF_ALPHA_DRIFT=1 \
    "$REPO_ROOT/bin/setup" drift --package alpha --format json

  [ "$status" -eq 1 ]
  run ruby -rjson -e 'data=JSON.parse(ARGF.read); abort unless data["summary"]["drifted"] == 1; abort unless data["packages"].any?{|pkg| pkg["package"]=="alpha" && pkg["status"]=="drifted"}' <<<"$output"
  [ "$status" -eq 0 ]
}
