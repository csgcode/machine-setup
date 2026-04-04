#!/usr/bin/env bats

load 'helpers/common.bash'

setup() {
  REPO_ROOT="$(repo_root)"
}

@test "help exits successfully" {
  run "$REPO_ROOT/bin/setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "missing group value is a usage error" {
  run "$REPO_ROOT/bin/setup" install --group
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing value for --group"* ]]
}

@test "selectors are rejected for non-install commands" {
  run "$REPO_ROOT/bin/setup" doctor --package bash
  [ "$status" -eq 2 ]
  [[ "$output" == *"Selectors are only supported with the install subcommand"* ]]
}

@test "conflicting install selectors are a usage error" {
  run "$REPO_ROOT/bin/setup" install --group core --package bash
  [ "$status" -eq 2 ]
  [[ "$output" == *"Use either --group or --package, not both"* ]]
}
