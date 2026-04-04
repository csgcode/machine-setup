#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
  FIXTURE_PACKAGES="$REPO_ROOT/test/fixtures/packages-basic.yaml"
  FIXTURE_GROUPS="$REPO_ROOT/test/fixtures/groups-basic.yaml"
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
