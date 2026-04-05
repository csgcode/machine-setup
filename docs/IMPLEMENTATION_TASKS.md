# Implementation Tasks

## Purpose

This document turns the project plan into an execution sequence. It should be
used with [PROJECT_PLAN.md](/Users/gokul/Dev/machine-setup/docs/PROJECT_PLAN.md)
and updated as work is completed.

## Execution Principles

- keep `./bin/setup` stable while refactoring
- prefer incremental migration over a full rewrite
- preserve idempotent package checks
- remove repo-owned dotfile copying before adding new config behavior
- keep manifests declarative and avoid hardcoded package logic where possible
- keep direct CLI and interactive flows backed by the same internal selection
  and execution logic
- prefer additive migration paths before deleting legacy structures
- preserve the entrypoint and useful flags, not the legacy group-centric CLI
  semantics

## Delivery Rules

- each task should land in a runnable state
- each phase should preserve `--dry-run` support
- new behavior should be covered by tests before legacy behavior is removed
- docs should be updated in the same change when user-facing behavior changes
- manifest validation should happen before any execution planning
- command handlers should delegate to shared planning and execution paths
- major workflows should be covered by end-to-end tests with stubbed external
  commands before the migration is considered complete

## Tracking

Use these task states when updating this document:

- pending
- in_progress
- completed
- blocked

Current progress:

- completed: `P0.0` through `P0.4`
- completed: `P1.1` through `P1.7`
- completed: `P2.1`
- completed: `P2.2`
- completed: `P3.1`
- completed: `P4.1`
- completed: `P4.2`
- completed: `P4.3`
- in_progress: `P4.4`

## Phase 4: Operational Polish

### P4.1 Add Structured Output

- add `--format text|json` for non-mutating reporting/system commands
- support JSON output for `list`, `doctor`, `status`, and `drift`
- keep text output stable as the default human-oriented format
- avoid mixing log noise into JSON output
- add tests for parseable JSON payloads and error handling

Definition of done:

- supported reporting/system commands can emit valid JSON
- JSON output preserves command exit-status behavior
- text output remains the default interface

### P4.2 Add Explicit Bootstrap Workflow

- add a first-class `bootstrap` command for `chezmoi` readiness
- validate `CHEZMOI_REPO_URL` configuration before init
- make bootstrap dry-run behavior explicit and predictable
- add tests for installed, missing, initialized, and missing-config cases

Definition of done:

- users can prepare `chezmoi` without running a package install
- bootstrap behavior is consistent across interactive and non-interactive use
- failures explain missing prerequisites clearly

### P4.3 Add CI Validation Workflow

- add GitHub Actions coverage for shell tests and manifest validation
- add shell linting with `shellcheck`
- ensure the workflow is deterministic and does not require local secrets
- document the local equivalent validation commands

Definition of done:

- pull requests can run the core validation suite automatically
- CI covers tests, shell lint, and manifest validation

### P4.4 Modernize Current-State Collection

- enhance `scripts/collect_current_state.sh` with manifest-aware missing detection
- add `manifests/collect-ignore.yaml` for persistent exclusions
- ensure ignored packages never appear in installed or missing sections
- add tests or script-level validation coverage for the collector

Definition of done:

- collection output distinguishes installed catalog packages from manifest-missing
- ignore rules are declarative and persistent
- reports are useful for catalog review without noisy false positives

## Phase 0: Stabilize Current Repository

### P0.0 Create A Migration Shell Around The Current CLI

- keep `./bin/setup` as the stable entrypoint
- identify which current commands are temporary compatibility behavior
- separate top-level argument parsing from package execution logic
- isolate legacy group/menu behavior so it can be deprecated cleanly

Definition of done:

- the entrypoint remains stable
- legacy `group` and menu behavior are clearly isolated behind compatibility
  paths
- new command work can proceed without further entangling the legacy CLI shape

### P0.1 Remove Destructive Dotfile Behavior

- remove `zshrc-curated` repo-owned copy behavior from install flow
- remove or deprecate dotfile mapping logic that writes directly into `$HOME`
- update docs to state that config is handled by `chezmoi`, not this repo
- decide whether `zshrc-curated` is removed entirely or converted into metadata
  for a future `chezmoi` target

Definition of done:

- no install path in this repo copies dotfiles into the user home directory
- dry-run no longer suggests direct `.zshrc` overwrites
- legacy dotfile copy code is either removed or clearly unreachable from the
  active install path

### P0.2 Fix Install Traversal Correctness

- add visited-state tracking to dependency resolution
- prevent duplicate package execution within a single command
- ensure explicit dependencies remain idempotent
- add circular dependency detection with a readable error path

Definition of done:

- `install --group shell --dry-run --yes` does not re-run the same package
  multiple times
- circular dependency failures identify the cycle clearly
- dependency traversal behavior is deterministic

### P0.3 Fix CLI Parsing and Error Handling

- guard missing argument values for `--group` and `--package`
- return controlled CLI errors instead of shell unbound-variable exits
- normalize command usage/help output
- make unsupported argument combinations fail with readable messages
- make compatibility commands explicit in help text during the migration period
- document and enforce exit code policy for usage errors versus runtime failures

Definition of done:

- malformed invocations fail with readable CLI errors
- help output matches actual supported commands
- exit codes are consistent for usage errors versus runtime failures
- help text makes it clear which commands are legacy compatibility paths

### P0.4 Add Regression Tests

- standardize on `bats-core`
- add tests for argument parsing
- add tests for manifest loading
- add tests for dependency traversal
- add tests for dry-run behavior
- add tests for duplicate dependency suppression
- add tests for cycle detection failures
- add helpers for fixture manifests and stubbed executables

Definition of done:

- current high-risk behavior is covered by automated tests
- phase 0 fixes are protected by tests
- the test harness can stub `brew`, `chezmoi`, and other external commands

## Phase 1: Desired-State Foundation

### P1.1 Redesign Manifest Schema

- define schema for packages
- define schema for tags
- define placeholder schema for profiles
- add top-level schema versioning
- add explicit dependency fields
- add optional config metadata fields
- add optional post-install metadata fields
- define validation rules for required and optional fields
- validate id uniqueness and referential integrity
- define a migration path from current manifests to the new schema

Recommended outputs:

- `manifests/packages.yaml`
- `manifests/tags.yaml`
- profile manifest placeholder or documented reserved schema
- legacy `groups` data either deprecated or reduced to compatibility-only usage

Definition of done:

- manifests can represent package install metadata, tags, dependencies, and
  `chezmoi` config targets without hardcoded package branching
- schema rules are documented clearly enough to validate future additions
- invalid manifests fail early with readable validation errors

### P1.2 Add Selection Engine

- resolve packages by id
- resolve packages by tag
- deduplicate selected packages
- expand explicit dependencies
- prepare shared selection output for both CLI and interactive flows
- normalize package ordering so execution is predictable
- return validation errors for unknown packages, tags, and dependency issues

Definition of done:

- one internal selection path powers both interactive and direct CLI commands
- the selection engine can be tested independently of command parsing

### P1.3 Add Execution Planner

- define a plan structure for package actions, config actions, and manual steps
- separate planning from execution so dry-run can render the same plan safely
- preserve execution ordering across dependencies and config application
- define result reporting structure for package and config outcomes
- add tests for plan construction and ordering from fixture manifests

Definition of done:

- command handlers can request a plan without executing it
- dry-run and real execution share the same plan structure
- result reporting is consistent across direct CLI and interactive flows
- planner tests cover dependency ordering, deduplication, and config actions

### P1.4 Add Desired-State Store

- implement config file loading from
  `${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml`
- implement state loading from
  `${XDG_STATE_HOME:-$HOME/.local/state}/machine-setup/state.yaml`
- define state file format for selected profile and local package overrides
- support environment override precedence for config
- define merge order across catalog, profile, local state, and CLI overrides
- define write behavior for saving local state

Definition of done:

- tool can read config and state consistently without hardcoded paths
- precedence rules are documented and covered by tests
- local state writes are idempotent and safe

### P1.5 Add Chezmoi Adapter

- detect whether `chezmoi` is installed
- bootstrap `chezmoi` if missing
- support private HTTPS init using `CHEZMOI_REPO_URL`
- support package-linked config application through `chezmoi` target paths
- support a small explicit base/shared config target
- define behavior when `chezmoi` is installed but not initialized
- define behavior when `CHEZMOI_REPO_URL` is missing in non-interactive mode
- define exact dry-run behavior for bootstrap, init, and apply operations
- add adapter tests with stubbed `chezmoi` commands and fixture outputs

Definition of done:

- tool can initialize and invoke `chezmoi` predictably for selected packages
- missing or invalid `chezmoi` configuration produces readable errors or
  interactive prompts, depending on mode
- dry-run does not mutate `chezmoi` state but shows what would happen
- adapter tests cover bootstrap, init, apply, and diff/report scenarios

### P1.6 Add New Command Surface

- support `install --package`
- support `install --tag`
- support `check --package`
- support `apply-config --package`
- ensure `install` applies linked config by default
- define whether `check` should support tags in the same phase
- keep `--dry-run` behavior consistent across new commands
- mark legacy `install --group` as compatibility behavior only
- add end-to-end tests for direct CLI commands using stubbed backends

Definition of done:

- each package can be operated independently from direct CLI
- direct commands share one execution backend instead of bespoke command paths
- the new command model is the documented primary interface
- direct-command tests cover output, exit codes, and dry-run behavior

### P1.7 Replace Current Menu With Guided Interactive Flow

- provide action selection
- provide package/tag selection
- show resolved package set before execution
- show package results, config results, and manual steps
- optionally persist the resulting selection into local state
- define a fallback when the terminal does not support the intended prompt UX
- add scripted interaction tests for the guided flow

Definition of done:

- interactive flow uses the same backend as direct CLI
- users can complete a basic install flow without remembering command syntax
- the hardcoded legacy menu is removed or reduced to a compatibility wrapper
- interaction tests cover at least one successful and one aborted flow

## Phase 2: Drift and Reporting

### P2.1 Add Config Drift Reporting

- integrate `chezmoi diff` or equivalent status checks
- report drift only for selected packages with config targets
- distinguish missing config targets from actual drift
- define output format for drift summary versus detailed drill-down
- add tests for clean, drifted, unavailable, and not-applicable states

Definition of done:

- drift output distinguishes clean, drifted, unavailable, and not-applicable
  states clearly
- drift checks are non-destructive and scriptable

### P2.2 Add Desired-State Reporting

- compare installed packages against selected desired state
- report selected-but-missing packages
- report installed-but-unselected packages
- keep reporting non-destructive
- ensure reports are based on resolved desired state, not just raw manifests
- add tests for merged profile and local override reporting

Definition of done:

- reporting reflects the merged desired state after profile and local overrides
- installed-but-unselected output is informative but does not imply removal

## Phase 3: Profiles

### P3.1 Add Repo-Defined Profiles

- add profile manifests
- resolve profiles into package selections
- merge profiles with machine-local include/exclude overrides
- define conflict behavior when profiles and local overrides disagree

Definition of done:

- `install --profile <id>` and interactive profile selection resolve through the
  same selection engine
- local overrides take effect predictably and are documented

## Cross-Cutting Technical Decisions To Lock During Implementation

- standardize on `bats-core`
- choose whether manifest validation is custom shell logic or delegated to Ruby
- define the internal execution contract before expanding commands further
- keep package-manager-specific logic isolated from selection and state logic
- define whether machine-readable output is deferred explicitly or introduced
  with drift/reporting commands

## Test Plan By Workflow

The following workflows should have explicit tests, not just incidental
coverage:

1. Legacy stability during migration

- `setup list`
- `setup doctor`
- `setup install --group <group> --dry-run --yes`
- malformed legacy invocations and compatibility help output

2. Manifest and planning correctness

- invalid manifest shape
- duplicate ids
- missing dependency references
- unknown tags
- deterministic dependency expansion
- config action inclusion in generated plans

3. Direct command workflows

- `setup install --package <id>` dry-run
- `setup install --package <id>` with dependency expansion
- `setup install --tag <tag>`
- `setup check --package <id>`
- `setup apply-config --package <id>`

4. Chezmoi workflows

- bootstrap when missing
- init from configured `CHEZMOI_REPO_URL`
- apply package-linked config targets
- missing target warnings
- drift reporting via stubbed `chezmoi diff`

5. Interactive workflows

- package selection path
- tag selection path
- cancelled execution path
- persistence to local state when enabled

Best-practice test split:

- unit-like shell tests for manifest, selection, planner, and adapter helpers
- end-to-end `bats` tests for public CLI workflows
- stub all external binaries in tests instead of invoking real `brew` or
  `chezmoi`

## Suggested Internal Module Order

Build or refactor internals in this order:

1. manifest/schema loader
2. selection engine
3. dependency resolver
4. execution planner
5. package installer backends
6. `chezmoi` adapter
7. desired-state store
8. CLI commands
9. interactive flow

## Recommended Build Order

1. P0.0 create a migration shell around the current CLI
2. P0.1 remove destructive dotfile behavior
3. P0.2 fix dependency traversal
4. P0.3 fix CLI parsing
5. P0.4 add regression tests
6. P1.1 redesign manifest schema
7. P1.2 add selection engine
8. P1.3 add execution planner
9. P1.4 add desired-state store
10. P1.5 add `chezmoi` adapter
11. P1.6 add new command surface
12. P1.7 add guided interactive flow
13. P2.1 add config drift reporting
14. P2.2 add desired-state reporting
15. P3.1 add profiles

## Immediate Next Step

Start with phase 0.0 and isolate the current CLI into a compatibility shell so
new command work does not deepen the existing coupling.

## Ready-To-Start Milestone

The project is ready to proceed into implementation when:

- phase 0 remains the active focus
- no new features are added before destructive current behavior is removed
- the first code changes are paired with regression tests where practical
