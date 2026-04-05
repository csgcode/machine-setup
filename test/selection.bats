#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
  FIXTURE_TAGS="$REPO_ROOT/test/fixtures/tags-basic.yaml"
}

@test "selection resolves package dependencies in deterministic order" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    selection_resolve_packages alpha
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'beta\nalpha' ]
}

@test "selection resolves tags and deduplicates packages" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    selection_resolve_inputs --package beta --tag test
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'beta\nalpha' ]
}

@test "selection fails for unknown tags" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    selection_resolve_tags missing
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'Unknown tag: missing'* ]]
}
