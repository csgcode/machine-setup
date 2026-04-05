#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
  FIXTURE_TAGS="$REPO_ROOT/manifests/tags.yaml"
  FIXTURE_PROFILES="$REPO_ROOT/manifests/profiles.yaml"
}

@test "manifest helpers list fixture packages" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    GROUPS_FILE="'"$FIXTURE_GROUPS"'"
    list_all_packages
  '
  [ "$status" -eq 0 ]
  [ "$output" = $'alpha\nbeta' ]
}

@test "manifest helpers return package dependencies" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    package_dependencies alpha
  '
  [ "$status" -eq 0 ]
  [ "$output" = 'beta' ]
}

@test "manifest helpers return package tags" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    PACKAGES_FILE="'"$FIXTURE_PACKAGES"'"
    package_tags alpha
  '
  [ "$status" -eq 0 ]
  [ "$output" = 'test' ]
}

@test "manifest schema validation passes for repo manifests" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    validate_manifest_schema
  '
  [ "$status" -eq 0 ]
}

@test "manifest helpers list repo profiles" {
  run bash -lc '
    source "'"$REPO_ROOT"'/lib/manifest.sh"
    list_all_profiles
  '
  [ "$status" -eq 0 ]
}
