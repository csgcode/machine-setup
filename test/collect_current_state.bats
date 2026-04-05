#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  TEST_REPORT_DIR="$BATS_TEST_TMPDIR/reports"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-collect.yaml"
  FIXTURE_IGNORE="$REPO_ROOT/test/fixtures/collect-ignore.yaml"

  mkdir -p "$TEST_HOME" "$TEST_BIN" "$TEST_REPORT_DIR"
  touch "$TEST_HOME/.shellpkg"

  cat > "$TEST_BIN/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  leaves)
    printf '%s\n' alpha-formula missing-formula
    ;;
  list)
    if [[ "${2:-}" == "--formula" ]]; then
      printf '%s\n' alpha-formula ignored-formula missing-formula dependency-formula
    elif [[ "${2:-}" == "--cask" ]]; then
      printf '%s\n' alpha-app ignored-cask missing-cask
    fi
    ;;
  services)
    if [[ "${2:-}" == "list" ]]; then
      printf '%s\n' "service started user"
    fi
    ;;
esac
EOF
  chmod +x "$TEST_BIN/brew"

  cat > "$TEST_BIN/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "list" && "${2:-}" == "-g" && "${5:-}" == "--parseable" ]]; then
  printf '%s\n' "/tmp/npm-global" "/tmp/npm-global/tool-one" "/tmp/npm-global/node_modules/@angular/cli" "/tmp/npm-global/ignored-tool"
  exit 0
fi

if [[ "${1:-}" == "list" && "${2:-}" == "-g" ]]; then
  printf '%s\n' "tool-one@1.0.0" "@angular/cli@2.0.0"
  exit 0
fi
EOF
  chmod +x "$TEST_BIN/npm"

  cat > "$TEST_BIN/rg" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$TEST_BIN/rg"
}

@test "collector reports manifest-tracked installs and untracked packages with ignores applied" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    COLLECT_IGNORE_FILE="$FIXTURE_IGNORE" \
    MACHINE_SETUP_REPORT_DIR="$TEST_REPORT_DIR" \
    COLLECT_TIMESTAMP="20260405-120000" \
    bash "$REPO_ROOT/scripts/collect_current_state.sh"

  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_REPORT_DIR/current-state-20260405-120000.md" ]

  run cat "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha [brew_formula:alpha-formula]"* ]]
  [[ "$output" == *"bravo [brew_cask:alpha-app]"* ]]
  [[ "$output" == *"missing-formula"* ]]
  [[ "$output" == *"missing-cask"* ]]
  [[ "$output" == *"tool-one"* ]]
  [[ "$output" == *"@angular/cli"* ]]
  [[ "$output" != *"shellpkg [shell_component:shellpkg]"* ]]
  [[ "$output" != *$'## Installed brew formulae missing from manifest\n```\ndependency-formula'* ]]
  [[ "$output" != *"ignored-formula"* ]]
  [[ "$output" != *$'## Installed brew formulae missing from manifest\n```\nignored-formula'* ]]
  [[ "$output" != *$'## Installed brew casks missing from manifest\n```\nignored-cask'* ]]
  [[ "$output" != *$'## Installed npm globals missing from manifest\n```\nignored-tool'* ]]
}
