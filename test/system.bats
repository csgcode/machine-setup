#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"

  mkdir -p "$TEST_BIN"

  cat > "$TEST_BIN/brew" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/brew"

  cat > "$TEST_BIN/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/git"

  cat > "$TEST_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/curl"
}

@test "list --format json emits package metadata as valid json" {
  run env \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    "$REPO_ROOT/bin/setup" list --format json

  [ "$status" -eq 0 ]
  run ruby -rjson -e 'data=JSON.parse(ARGF.read); abort unless data["packages"].is_a?(Array); abort unless data["packages"].any?{|pkg| pkg["id"]=="alpha" && pkg["installer_kind"]=="brew_formula"}' <<<"$output"
  [ "$status" -eq 0 ]
}

@test "doctor --format json emits machine-readable checks" {
  run env \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    "$REPO_ROOT/bin/setup" doctor --format json

  [ "$status" -eq 0 ]
  run ruby -rjson -e 'data=JSON.parse(ARGF.read); abort unless data["summary"]["missing"] == 0; abort unless data["checks"].any?{|check| check["command"]=="brew" && check["status"]=="ok"}' <<<"$output"
  [ "$status" -eq 0 ]
}
