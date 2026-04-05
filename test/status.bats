#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  TEST_BIN="$BATS_TEST_TMPDIR/bin"
  TEST_STATE="$BATS_TEST_TMPDIR/state.yaml"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-status.yaml"
  FIXTURE_TAGS="$REPO_ROOT/test/fixtures/tags-status.yaml"
  FIXTURE_PROFILES="$REPO_ROOT/test/fixtures/profiles-status.yaml"

  mkdir -p "$TEST_HOME" "$TEST_BIN"

  cat > "$TEST_BIN/alpha" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/alpha"

  cat > "$TEST_BIN/beta" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/beta"

  cat > "$TEST_BIN/delta" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_BIN/delta"

  cat > "$TEST_STATE" <<'EOF'
profile: work-laptop
packages:
  include:
    - gamma
  exclude:
    - beta
tags:
  include: []
  exclude: []
EOF
}

@test "status reports merged desired state with profile and local overrides" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    MACHINE_SETUP_STATE_PATH="$TEST_STATE" \
    "$REPO_ROOT/bin/setup" status

  [ "$status" -eq 1 ]
  [[ "$output" == *"Desired packages:"* ]]
  [[ "$output" == *"  - delta"* ]]
  [[ "$output" == *"  - alpha"* ]]
  [[ "$output" == *"  - gamma"* ]]
  [[ "$output" == *"[desired-installed] delta"* ]]
  [[ "$output" == *"[desired-installed] alpha"* ]]
  [[ "$output" == *"[desired-missing] gamma"* ]]
  [[ "$output" == *"[installed-unselected] beta"* ]]
  [[ "$output" == *"Summary: desired=3 installed=2 missing=1 installed-unselected=1"* ]]
}

@test "status warns when no desired state is configured" {
  run env \
    HOME="$TEST_HOME" \
    PATH="$TEST_BIN:/usr/bin:/bin" \
    PACKAGES_FILE="$FIXTURE_PACKAGES" \
    TAGS_FILE="$FIXTURE_TAGS" \
    PROFILES_FILE="$FIXTURE_PROFILES" \
    MACHINE_SETUP_STATE_PATH="$BATS_TEST_TMPDIR/empty-state.yaml" \
    "$REPO_ROOT/bin/setup" status

  [ "$status" -eq 0 ]
  [[ "$output" == *"No desired state is configured"* ]]
}
