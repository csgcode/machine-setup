#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  TEST_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TEST_HOME"
}

@test "state paths default to XDG locations" {
  run bash -lc '
    export HOME="'"$TEST_HOME"'"
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    printf "%s\n%s\n" "$(state_config_path)" "$(state_state_path)"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $TEST_HOME'/.config/machine-setup/config.yaml'$'\n'$TEST_HOME'/.local/state/machine-setup/state.yaml' ]
}

@test "chezmoi repo url env override wins over config file" {
  run bash -lc '
    export HOME="'"$TEST_HOME"'"
    export MACHINE_SETUP_CONFIG_PATH="'"$BATS_TEST_TMPDIR"'/config.yaml"
    export CHEZMOI_REPO_URL="https://env.example/repo.git"
    cat > "$MACHINE_SETUP_CONFIG_PATH" <<'"'"'EOF'"'"'
chezmoi:
  repo_url: https://file.example/repo.git
EOF
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    state_get_config_value chezmoi.repo_url
  '
  [ "$status" -eq 0 ]
  [ "$output" = 'https://env.example/repo.git' ]
}

@test "state write and read round-trip machine state" {
  run bash -lc '
    export HOME="'"$TEST_HOME"'"
    export MACHINE_SETUP_STATE_PATH="'"$BATS_TEST_TMPDIR"'/state.yaml"
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    state_write_machine_state \
      --profile work-laptop \
      --include-package alpha \
      --exclude-package beta \
      --include-tag shell \
      --exclude-tag core
    printf "%s\n---\n%s\n---\n%s\n---\n%s\n---\n%s\n" \
      "$(state_get_selected_profile)" \
      "$(state_get_package_includes)" \
      "$(state_get_package_excludes)" \
      "$(state_get_tag_includes)" \
      "$(state_get_tag_excludes)"
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'work-laptop\n---\nalpha\n---\nbeta\n---\nshell\n---\ncore' ]
}

@test "state merge applies local overrides then CLI overrides" {
  run bash -lc '
    export HOME="'"$TEST_HOME"'"
    export MACHINE_SETUP_STATE_PATH="'"$BATS_TEST_TMPDIR"'/state.yaml"
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/core/state.sh"
    state_write_machine_state \
      --include-package gamma \
      --exclude-package beta
    state_merge_package_selection alpha beta --include delta --exclude gamma
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'alpha\ndelta' ]
}
