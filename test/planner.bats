#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
  FIXTURE_TAGS="$REPO_ROOT/test/fixtures/tags-basic.yaml"
}

@test "planner builds package actions in resolved dependency order" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    source "'"$REPO_ROOT"'/lib/core/planner.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    planner_build_install_plan_from_packages alpha
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *$'package\tbeta\tbrew_formula\tbeta'* ]]
  [[ "$output" == *$'package\talpha\tbrew_formula\talpha'* ]]
}

@test "planner emits config and manual actions when metadata exists" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    source "'"$REPO_ROOT"'/lib/core/planner.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    planner_build_install_plan_from_packages alpha
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *$'config\talpha\tchezmoi_tag\talpha-config'* ]]
  [[ "$output" == *$'manual_step\talpha\tReview alpha after install.'* ]]
}

@test "planner can build plans from mixed package and tag inputs" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    source "'"$REPO_ROOT"'/lib/core/planner.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    planner_build_install_plan_from_inputs --package beta --tag test
  '
  [ "$status" -eq 0 ]
  [ "$(count_matches $'package\tbeta\tbrew_formula\tbeta' "$output")" -eq 1 ]
  [ "$(count_matches $'package\talpha\tbrew_formula\talpha' "$output")" -eq 1 ]
}
