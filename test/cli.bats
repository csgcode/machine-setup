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
  [[ "$output" == *"Selectors are only supported with install, check, apply-config, and drift"* ]]
}

@test "install rejects mixing group and package selectors" {
  run "$REPO_ROOT/bin/setup" install --group core --package bash
  [ "$status" -eq 2 ]
  [[ "$output" == *"Use either --group or package/tag/profile selectors, not both"* ]]
}

@test "missing tag value is a usage error" {
  run "$REPO_ROOT/bin/setup" install --tag
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing value for --tag"* ]]
}

@test "missing profile value is a usage error" {
  run "$REPO_ROOT/bin/setup" install --profile
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing value for --profile"* ]]
}

@test "missing format value is a usage error" {
  run "$REPO_ROOT/bin/setup" status --format
  [ "$status" -eq 2 ]
  [[ "$output" == *"Missing value for --format"* ]]
}

@test "unsupported format is a usage error" {
  run "$REPO_ROOT/bin/setup" status --format yaml
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unsupported format: yaml"* ]]
}

@test "group selector is rejected for apply-config" {
  run "$REPO_ROOT/bin/setup" apply-config --group shell
  [ "$status" -eq 2 ]
  [[ "$output" == *"--group is only supported with install"* ]]
}

@test "drift is included in help output" {
  run "$REPO_ROOT/bin/setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"setup drift --package <id> [--tag <tag> ...]"* ]]
}

@test "status is included in help output" {
  run "$REPO_ROOT/bin/setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"setup status"* ]]
}

@test "bootstrap is included in help output" {
  run "$REPO_ROOT/bin/setup" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"setup bootstrap"* ]]
}

@test "drift requires a selector" {
  run "$REPO_ROOT/bin/setup" drift
  [ "$status" -eq 2 ]
  [[ "$output" == *"drift requires --package, --tag, or --profile"* ]]
}
