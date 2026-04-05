# Project Plan

## Goal

Reposition this repository from a narrow machine setup script into a declarative
macOS bootstrap tool for desired state management.

For a new Apple Silicon Mac, the tool should let the user choose software to
install, install it idempotently, and apply matching configuration through
`chezmoi` only for the selected software.

This repository should remain separate from the `chezmoi` repository.

## Locked Decisions

These decisions are now considered settled for planning purposes.

- Platform scope for phase 1: macOS Apple Silicon only.
- Repository split: keep this repository separate from the `chezmoi`
  repository.
- `chezmoi` bootstrap: supported in phase 1.
- `chezmoi` source: private HTTPS repository configured through
  `CHEZMOI_REPO_URL`.
- Default config path: `${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml`.
- Default state path: `${XDG_STATE_HOME:-$HOME/.local/state}/machine-setup/state.yaml`.
- Allow environment variables to override file-based config where appropriate.
- Selection model for phase 1: individual packages and tags.
- Desired-state persistence: hybrid model using repo-defined profiles/catalog
  plus machine-local overrides.
- Config application model: package-linked `chezmoi` targets, with explicit
  `chezmoi` target paths as the phase 1 mechanism.
- Default command behavior: `install` should install software and apply linked
  config by default.
- Shared config policy: handle shared/global config through a small explicit
  base config target, not by implicit package inference.
- Dependencies: support explicit package dependencies in manifests.
- UX level for phase 1: guided interactive terminal flow, not a full-screen
  TUI.
- Manifest evolution: version the manifest schema and validate referential
  integrity before execution.
- Execution architecture: use a selection -> plan -> execute -> report flow
  instead of letting CLI commands call installers directly.
- Dry-run semantics: every mutating action, including package install,
  `chezmoi` bootstrap, and config apply, must have a predictable non-mutating
  preview mode.
- Test strategy: use `bats-core` as the primary shell test framework, with
  layered tests for units, planner behavior, and end-to-end CLI workflows.
- Preserve `./bin/setup` as the entrypoint, but do not preserve the current
  group-centric CLI shape as a long-term public contract.
- Use a temporary compatibility layer for legacy commands during migration,
  then deprecate them.

## Product Direction

### Phase 1

- Support macOS Apple Silicon only.
- Bootstrap `chezmoi` if missing.
- Allow configuring `CHEZMOI_REPO_URL` for initializing the separate private
  `chezmoi` repository.
- Use interactive terminal selection, not a full-screen TUI.
- Support software selection by:
  - individual package
  - tags
- Keep direct CLI entrypoints for isolated actions:
  - install one package
  - check one package
  - apply config for one package
- Treat config as `chezmoi`-managed only. This repository should stop copying
  dotfiles directly.
- Use package-linked `chezmoi` target paths for package-specific config
  targeting.
- Support a hybrid desired-state model:
  - repo-defined catalog and future profiles
  - machine-local overrides for per-machine customization
- Make `install` apply linked config by default.
- Focus drift reporting primarily on configuration drift via `chezmoi`.
- Keep legacy commands only as compatibility shims where they reduce migration
  risk.

### Later Phases

- saved profiles
- richer interactive UI
- Ubuntu support
- desired-state reconciliation reports across packages and config
- optional strict mode and policy controls
- machine-readable command output for reporting workflows
- CI-backed validation and catalog hygiene automation

## Repository Boundaries

### This Repository Owns

- package catalog
- tags
- future profiles
- installer backends
- selection workflow
- orchestration logic
- drift and status reporting
- `chezmoi` integration metadata

### Chezmoi Repository Owns

- actual dotfiles
- config templates
- config scripts
- machine/user-specific rendering logic
- config drift detection and apply behavior

## Key Decisions

### 1. Selection Model

Use a declarative manifest model.

- Packages are the atomic unit.
- Tags describe user context, such as `work`, `personal`, `shell`, `database`.
- Profiles come later as saved selections composed from package ids and tags.

Why:

- avoids hardcoded menus
- keeps CLI and interactive flows powered by the same metadata
- makes future Linux support easier

### 2. Config Integration Model

Use explicit package-to-config mapping.

Each package may declare an optional config target. The config target should map
to `chezmoi` behavior, with explicit target paths as the preferred phase 1
mechanism.

Recommended phase 1 contract:

- package selected
- package installed or verified
- if package has a config target, run `chezmoi` for that target only
- if package participates in shared/global config, handle that through a small
  explicit base target rather than implicit package resolution

This repository should not copy config files directly.

### 3. Direct CLI Contract

Each package should support isolated operations.

Examples:

```bash
./bin/setup install --package wezterm
./bin/setup check --package wezterm
./bin/setup apply-config --package wezterm
./bin/setup install --tag work
```

The same package definition must power both direct CLI and interactive flows.
By default, `install` should install software and apply linked config together.
`apply-config` remains available for isolated reruns.

Preserve only these CLI qualities from the current implementation:

- `./bin/setup` entrypoint
- direct command invocation
- `--dry-run`
- idempotent checks before install

Do not preserve these legacy semantics as long-term design constraints:

- `group` as the primary installation model
- shell-component-specific branching in the top-level CLI
- the current hardcoded interactive menu structure

Modern CLI expectations for this project:

- stable and documented exit codes for usage errors versus execution failures
- readable text output for humans in phase 1
- a clean internal contract so machine-readable output can be added later
- consistent dry-run behavior across direct and interactive flows

### 4. Execution Model

Do not let command handlers perform package resolution, dependency expansion,
installer dispatch, and config application inline.

Recommended internal flow:

- parse command and flags
- resolve desired selection
- validate manifests and dependencies
- build an execution plan
- execute or dry-run the plan
- report package results, config results, and manual follow-up

Why:

- keeps the CLI thin
- makes direct commands and interactive flows share the same backend
- makes testing easier because planning and execution can be validated
  separately
- avoids repeating the current `lib/cli.sh` coupling

### 5. Drift Strategy

Primary focus is config drift.

Recommended reporting split:

- package state: installed / missing / unknown
- config state: managed / drifted / unavailable / not-applicable

Phase 1 should integrate `chezmoi diff` or equivalent status checks for
selected packages with config targets.

To support later reconciliation, desired state should come from:

- repo-defined catalog and future profiles
- machine-local selection state and overrides

### 6. Missing Config Target Behavior

Recommended behavior:

- interactive mode: warn and ask whether to continue
- non-interactive mode: warn and continue
- future strict mode: fail if requested config target is missing

### 7. Post-Install Guidance

Add declarative metadata for non-automated follow-up.

Recommended optional package fields:

- `notes`
- `manual_steps`
- `links`

Why:

- some apps require macOS permissions or login
- keeps user guidance in manifests instead of shell logic

### 8. Manifest Validation Rules

The schema should be versioned from the start, even if phase 1 only has one
supported version.

Recommended invariants:

- package ids are unique
- tag ids are unique
- profile ids are unique
- `depends_on` references valid package ids
- config targets use a supported strategy
- required installer fields are present for the chosen installer kind
- unknown fields either fail validation or are explicitly ignored by policy

Why:

- avoids silent manifest drift
- makes future Linux support and profile expansion safer
- gives a clean migration path when the schema evolves

### 9. Testing Strategy

Use a layered testing model instead of relying only on command-level smoke
tests.

Recommended test layers:

- manifest and validation tests
- selection and dependency resolution tests
- execution planner tests
- adapter tests for installer and `chezmoi` integration with stubbed commands
- end-to-end CLI workflow tests with fixture manifests and fake backends

Recommended framework choice:

- use `bats-core` as the primary shell testing framework

Why:

- it is the most common modern convention for Bash CLI testing
- it works well for command-level assertions and exit-code checks
- it supports fixtures and helper libraries cleanly enough for this repo
- it is easier to maintain than inventing custom shell test harnesses

Major workflows that must be covered before the migration is considered safe:

- `setup list`
- `setup doctor`
- legacy compatibility commands during the migration window
- `install --package` dry-run and real planning paths
- `install --tag` resolution and deduplication
- `check --package`
- `apply-config --package`
- interactive guided flow with deterministic input scripting
- drift reporting with `chezmoi` output stubbed

Testing principles:

- stub external tools such as `brew`, `chezmoi`, and `git`
- keep tests non-mutating by default
- prefer fixture manifests over mutating the real repo manifests in tests
- verify both human-readable output and exit status for major workflows
- separate planner assertions from execution assertions where possible

## Proposed Manifest Model

The exact shape can evolve, but this is the intended direction.

```yaml
schema_version: 1

packages:
  - id: wezterm
    name: WezTerm
    platform:
      - macos
    installer:
      kind: brew_cask
      package: wezterm
    check:
      command: brew list --cask wezterm >/dev/null 2>&1
    tags:
      - terminal
      - personal
      - work
    depends_on: []
    config:
      target: wezterm
      strategy: chezmoi_target
      optional: true
    notes:
      - "May require default terminal preference changes."

tags:
  - id: work
    description: Work-related tools and config.

profiles:
  - id: work-laptop
    packages:
      - wezterm
      - awscli
    tags:
      - work

state:
  profile: work-laptop
  packages:
    include:
      - codex
    exclude:
      - awscli
```

Intended storage model:

- repo manifests define catalog, tags, and future profiles
- machine-local state stores selected profile and per-machine overrides

Recommended default locations:

- config: `${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml`
- state: `${XDG_STATE_HOME:-$HOME/.local/state}/machine-setup/state.yaml`

## Command Model

### Interactive

Start with a guided selector instead of a full TUI library.

Suggested flow:

1. Choose action:
   - install selected software
   - check current state
   - apply config for selected software
   - review drift
2. Choose selection mode:
   - individual packages
   - tags
3. Confirm selected packages
4. Run package actions
5. Run config apply for selected packages with config targets
6. Print any manual steps
7. Optionally save the resulting selection as local machine state

### Direct CLI

Minimum phase 1 commands:

```bash
./bin/setup install --package <id>
./bin/setup install --tag <tag>
./bin/setup check --package <id>
./bin/setup apply-config --package <id>
./bin/setup drift --package <id>
```

Likely convenience commands to add shortly after:

```bash
./bin/setup install --profile <id>
./bin/setup drift
./bin/setup state save
```

Legacy compatibility commands may exist temporarily during migration, but the
target command model is package, tag, profile, config, and drift driven.

## Architecture Changes Needed

### Remove Current Problem Areas

- remove legacy CLI coupling between command parsing, selection, and execution
- remove direct dotfile copying from install flow
- remove hardcoded shell component behavior where declarative metadata is enough
- prevent duplicate dependency execution
- add safe argument parsing
- stop coupling package install success to broad group execution
- de-emphasize `group` as the primary orchestration concept

### Migration Strategy

Refactor toward a layered internal architecture while keeping `./bin/setup`
usable throughout the transition.

Migration rules:

- keep `./bin/setup` stable as the entrypoint
- move new behavior behind a new internal execution model
- keep legacy `group` flows only as a temporary compatibility shell
- remove compatibility behavior once package/tag/profile flows are complete and
  documented

### Introduce New Layers

- command handlers
- manifest/schema loader
- package selection engine
- tag resolver
- dependency resolver
- execution planner
- config target resolver
- `chezmoi` adapter
- desired-state store
- status/drift reporter
- interactive selector

## Recommended Phases

### Phase 0: Cleanup and Stabilize Current Repository

- separate command parsing from install execution enough to enable migration
- fix destructive `zshrc` handling by removing repo-owned dotfile copy behavior
- fix duplicate dependency traversal
- fix argument parsing errors
- add tests for parsing, dependency resolution, and dry-run behavior
- document current limitations clearly

### Phase 1: New Desired-State Core

- redesign manifests around packages + tags + optional config target
- introduce a new command model centered on package and tag actions
- add package selection by individual package and tag
- add `chezmoi` bootstrap/install check
- add support for `CHEZMOI_REPO_URL`
- add `chezmoi` apply for package-linked config targets
- add machine-local desired-state storage with repo-defined catalog inputs
- add direct CLI commands for package install, check, and config apply
- replace the legacy menu with a guided interactive selector backed by the new
  command model
- keep macOS-only installer backend

### Phase 2: Drift and Reporting

- add config drift checks using `chezmoi diff`
- distinguish package drift from config drift
- add machine state report command
- improve missing/unselected reporting

### Phase 3: Profiles

- add saved profile manifests
- support profile selection in interactive flow
- support `install --profile <id>`

### Phase 4: Platform Expansion

- add Ubuntu support
- move package definitions toward platform-specific installer blocks

## Open Decisions

These are known but not blocking for initial design work.

- exact machine-local state file format
- exact merge rules between file config and environment overrides
- whether any package should support alternate config strategies besides
  `chezmoi` tags in phase 1

## Best-Practice Defaults

Until overridden, use these defaults:

- keep bootstrap repo and `chezmoi` repo separate
- keep package metadata declarative
- use package-linked `chezmoi` target paths
- preserve the entrypoint, not the legacy CLI semantics
- route both direct CLI and interactive flows through the same backend
- prefer warnings over hard failure when config target is missing
- avoid uninstall/remove behavior in this phase
- expose manual steps declaratively
- use hybrid desired state: repo-defined catalog plus machine-local overrides
- make `install` apply config by default

## Initial Task List

- audit and remove repo-owned dotfile application path
- define new manifest schema for packages, tags, and config targets
- define machine-local desired-state file format and storage path
- add parser support for tags
- add parser support for explicit dependencies
- add package selection resolver
- add machine-local override merge logic
- add `chezmoi` detection/bootstrap adapter
- add `CHEZMOI_REPO_URL` configuration support
- add config apply command path
- add direct CLI subcommands: `install`, `check`, `apply-config`, `drift`
- replace current menu with guided selector
- create tests around manifest parsing and selection resolution
- document expected `chezmoi` integration workflow

## Phase 1 Candidate Catalog

These packages are approved as the starting shortlist for manifest redesign,
pending later curation into tags and config targets.

### CLI

- chezmoi
- bash
- bat
- fzf
- glab
- gnu-sed
- nvm
- pipx
- pre-commit
- task
- tmux
- yq

### GUI

- aerospace
- codex
- maccy

## Source Of Truth

Use this document as the planning source of truth for continued work in this
repository unless a newer decision document explicitly supersedes part of it.
