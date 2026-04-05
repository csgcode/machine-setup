#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
  FIXTURE_TAGS="$REPO_ROOT/test/fixtures/tags-basic.yaml"
  FIXTURE_PROFILES="$REPO_ROOT/test/fixtures/profiles-basic.yaml"
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
    PROFILES_FILE="'"$FIXTURE_PROFILES"'"
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
    PROFILES_FILE="'"$FIXTURE_PROFILES"'"
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
    PROFILES_FILE="'"$FIXTURE_PROFILES"'"
    selection_resolve_tags missing
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *'Unknown tag: missing'* ]]
}

@test "selection resolves profiles through the same dependency path" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/common/log.sh"
    source "'"$REPO_ROOT"'/lib/common/checks.sh"
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    source "'"$REPO_ROOT"'/lib/core/selection.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    TAGS_FILE="'"$FIXTURE_TAGS"'"
    PROFILES_FILE="'"$FIXTURE_PROFILES"'"
    selection_resolve_inputs --profile starter
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'beta\nalpha' ]
}
