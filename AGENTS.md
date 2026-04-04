# AGENTS.md

## Purpose
This repo manages an idempotent macOS dev machine setup CLI.
Current scope is `core` + `shell` groups only.

## Current State
- CLI entrypoint: `bin/setup`
- Manifests: `manifests/groups.yaml`, `manifests/packages.yaml`
- Installers: `lib/installers/*`
- Curated zsh config: `dotfiles/zshrc.base`
- Docs: `docs/USAGE.md`, `docs/ADDING_PACKAGES.md`, `docs/DECISIONS.md`

## Next Steps (Priority Order)
1. Validate current flows in dry-run mode only:
   - `./bin/setup doctor`
   - `./bin/setup list`
   - `./bin/setup install --group core --dry-run --yes`
   - `./bin/setup install --group shell --dry-run --yes`
2. Add automated tests (shellspec or bats) for:
   - argument parsing
   - manifest loading
   - idempotent skip behavior
   - dry-run behavior
3. Add CI checks:
   - shell lint (`shellcheck`)
   - formatting/lint gate for YAML and shell scripts
   - test execution
4. Improve dependency handling:
   - detect circular `depends_on`
   - prevent duplicate package execution in recursive installs
5. Extend package coverage with new groups (when requested):
   - `backend` (postgresql, redis, poetry)
   - `cloud` (awscli, kubectl, optional k8s helpers)
6. Add explicit rollback notes for dotfile changes and improve backup naming strategy.

## New Requested Tasks (Queued)
1. Enhance collect script with missing detection + ignore list:
   - `scripts/collect_current_state.sh` should collect installed packages and identify missing packages from manifests.
   - Add persistent ignore list file (for example `manifests/collect-ignore.yaml`).
   - Ignored packages must never appear in later collect outputs (installed/missing views).
2. Add tag-aware install mode:
   - Support tags like `work`, `personal` on package definitions.
   - Add install flow for tag selection (for example `install --tag work`).
   - Ensure tags can coexist with groups and remain idempotent.
3. Make install flow fully interactive by default:
   - Keep non-interactive mode available for automation (`--yes`).
   - Interactive prompts should guide group/tag/package selection.
   - Interactive path should support per-package confirmation.

## Operating Rules
- Keep installs idempotent (`check` must pass before skipping).
- Prefer declarative changes in manifests over hardcoding logic.
- Any new package must include:
  - `id`, `group`, `manager`, `check`, `install`
  - optional `depends_on`, `service`
- Default validation should be non-mutating (`--dry-run`) unless explicitly requested.
- Do not store secrets/tokens in this repo.

## Task Template
When adding a new setup capability:
1. Update `manifests/packages.yaml`
2. Update `manifests/groups.yaml`
3. Add/extend installer handler if needed
4. Validate with dry-run
5. Update docs in `docs/USAGE.md` and `docs/DECISIONS.md`

## Quick Commands
- Interactive: `./bin/setup`
- List: `./bin/setup list`
- Doctor: `./bin/setup doctor`
- Group dry-run: `./bin/setup install --group <group> --dry-run --yes`
- Package dry-run: `./bin/setup install --package <id> --dry-run --yes`
