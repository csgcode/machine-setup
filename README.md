# machine-setup

Declarative macOS bootstrap CLI for package installation, desired-state
selection, and `chezmoi`-managed configuration.

This repository does not own your dotfiles. It installs software, tracks
desired state, bootstraps `chezmoi`, and applies only the configuration targets
linked to the software you select.

## Current Scope

- platform: macOS on Apple Silicon
- package selection: package, tag, profile
- config management: separate `chezmoi` repository
- state model: repo manifests plus machine-local overrides
- legacy support: `install --group` still exists as a compatibility path

## How It Works

`machine-setup` follows a declarative flow:

1. You select software by package, tag, profile, or the guided interactive flow.
2. The CLI resolves dependencies from manifests.
3. It builds an execution plan.
4. It installs missing software idempotently.
5. It applies linked `chezmoi` targets for the selected software.
6. It can save your selection to local machine state for later `status` and
   `drift` checks.

## Prerequisites

Required:

- macOS Apple Silicon
- `bash`
- `git`
- `curl`
- `ruby`
- Homebrew

Recommended:

- a private `chezmoi` repository reachable over HTTPS

Check local prerequisites:

```bash
./bin/setup doctor
```

## Repository Layout

- entrypoint: `./bin/setup`
- package catalog: `manifests/packages.yaml`
- tags: `manifests/tags.yaml`
- profiles: `manifests/profiles.yaml`
- CLI docs: `docs/USAGE.md`
- implementation tracker: `docs/IMPLEMENTATION_TASKS.md`
- validation: `scripts/validate.sh`

## Initial Setup

### 1. Clone the repository

```bash
git clone <this-repo-url>
cd machine-setup
```

### 2. Configure `chezmoi`

Set your `chezmoi` repo URL through an environment variable:

```bash
export CHEZMOI_REPO_URL="https://example.com/your-dotfiles.git"
```

Or store it in the config file:

Path:

```bash
${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml
```

Example:

```yaml
chezmoi:
  repo_url: https://example.com/your-dotfiles.git
  base_target: shell-base
```

`chezmoi.base_target` is optional. If set, it is applied once alongside
package-specific config targets.

Environment variables override config file values where supported.

### 3. Bootstrap `chezmoi`

```bash
./bin/setup bootstrap
```

This will:

- install `chezmoi` if it is missing
- initialize it from `CHEZMOI_REPO_URL` if it has not been initialized yet

Preview without changing anything:

```bash
./bin/setup bootstrap --dry-run
```

## Quick Start

List available packages:

```bash
./bin/setup list
```

Run the guided flow:

```bash
./bin/setup
```

Install a package:

```bash
./bin/setup install --package oh-my-zsh
```

Install by tag:

```bash
./bin/setup install --tag shell
```

Check desired-state status:

```bash
./bin/setup status
```

Check config drift:

```bash
./bin/setup drift --tag shell
```

Recommended first-run sequence on a new Mac:

```bash
./bin/setup doctor
./bin/setup bootstrap
./bin/setup list
./bin/setup
./bin/setup status
```

## Commands

This CLI has two ways to work:

- guided mode for a human setting up a machine
- direct subcommands for repeatable or scriptable operations

If you are unsure where to start, use the interactive flow first.

### `setup`

Use this when:

- you are setting up a new machine manually
- you want the CLI to guide package, tag, or profile selection
- you want to review resolved packages before execution
- you want to save the chosen selection into local state

Command:

```bash
./bin/setup
```

What it does:

- choose `install`, `check`, or `apply-config`
- choose software by package, tag, or profile
- preview the resolved package set
- save the selection into local machine state

Typical use case:

- first-time setup of a new Mac
- updating local desired state after choosing a new set of tools

### `setup list`

Use this when:

- you want to see what the repo currently knows how to manage
- you want package ids before using `install`, `check`, or `apply-config`
- you want to inspect the managed catalog in automation

Command:

```bash
./bin/setup list
./bin/setup list --format json
```

What it returns:

- package ids
- groups
- installer kinds

Typical use case:

- check whether a tool exists in the catalog before trying to install it

### `setup doctor`

Use this when:

- you want a quick prerequisite check on the current machine
- you are not sure whether the machine is ready to run installs
- you want a non-mutating health check before bootstrap or install

Command:

```bash
./bin/setup doctor
./bin/setup doctor --format json
```

What it checks:

- `brew`
- `git`
- `curl`
- `ruby`

Typical use case:

- first command to run on a fresh machine
- preflight check in docs or automation

### `setup bootstrap`

Use this when:

- `chezmoi` is not installed yet
- `chezmoi` is installed but not initialized on this machine
- you want the config-management side ready before package-linked config apply

Command:

```bash
./bin/setup bootstrap
./bin/setup bootstrap --dry-run
./bin/setup bootstrap --format json
```

What it does:

- installs `chezmoi` if missing
- initializes it from `CHEZMOI_REPO_URL` if needed
- does not require you to run `chezmoi` manually first

Typical use case:

- one-time machine bootstrap before any config-managed install flow

### `setup install`

Use this when:

- you want to install software selected by package, tag, or profile
- you want package install and linked config apply in one command
- you want idempotent install behavior

Command:

Install individual packages:

```bash
./bin/setup install --package bash
./bin/setup install --package oh-my-zsh --package zsh-z
```

Install by tag:

```bash
./bin/setup install --tag core
./bin/setup install --tag shell
```

Install by profile:

```bash
./bin/setup install --profile work-laptop
```

What it does:

- `install` installs missing software and applies linked config by default
- package, tag, and profile selectors can be combined
- `--group` still exists, but only as a legacy compatibility path

Typical use cases:

- install just one tool:
```bash
./bin/setup install --package bash
```

- install a themed set of tools:
```bash
./bin/setup install --tag shell
```

- apply a repeatable repo-defined selection:
```bash
./bin/setup install --profile work-laptop
```

Legacy compatibility examples:

```bash
./bin/setup install --group core
./bin/setup install --group shell
```

### `setup check`

Use this when:

- you want to know which selected packages are installed or missing
- you want a non-mutating verification command
- you want to validate a package/tag/profile selection before installing

Command:

```bash
./bin/setup check --package bash
./bin/setup check --tag shell
./bin/setup check --profile work-laptop
```

What it does:

- resolves the selected packages
- runs package check commands only
- reports installed vs missing without changing the machine

Typical use case:

- audit whether a machine already has the selected tools

### `setup apply-config`

Use this when:

- the software is already installed and you only want config applied again
- you updated your `chezmoi` repo and want to re-apply package-linked config
- you want to separate config operations from package installation

Command:

```bash
./bin/setup apply-config --package oh-my-zsh
./bin/setup apply-config --tag shell
./bin/setup apply-config --profile work-laptop
```

What it does:

- skips package installers
- runs only the config actions linked to the selected packages

Typical use case:

- reapply shell configuration after changing the dotfiles repo

### `setup status`

Use this when:

- you want to compare current machine installs against saved desired state
- you want to know what is missing on a new machine
- you want to know what is installed but not part of desired state

Command:

```bash
./bin/setup status
./bin/setup status --format json
```

`status` compares your merged desired state against what is currently installed.

If no desired state has been saved yet, it warns instead of failing.

Typical use cases:

- after using the interactive flow and saving selection, run:
```bash
./bin/setup status
```

- for scripting or tooling:
```bash
./bin/setup status --format json
```

Important distinction:

- `status` answers: "Which desired packages are missing on this machine?"
- `list` answers: "What can this repo manage?"

### `setup drift`

Use this when:

- you want to check whether selected config-managed tools have drifted from `chezmoi`
- you want config drift reporting without reinstalling anything
- you want target-scoped config checks

Command:

```bash
./bin/setup drift --package oh-my-zsh
./bin/setup drift --tag shell
./bin/setup drift --profile work-laptop
./bin/setup drift --format json --tag shell
```

`drift` uses `chezmoi` to report config state for selected packages.

Typical use case:

- after editing config locally or changing dotfiles, verify shell config drift:
```bash
./bin/setup drift --tag shell
```

### Legacy compatibility: `install --group`

Use this only when:

- you are still relying on older group-based usage
- you need temporary compatibility with the pre-migration workflow

This is not the long-term model. Prefer packages, tags, and profiles for new
usage.

## Selectors

### Packages

Atomic units in `manifests/packages.yaml`.

Use packages when:

- you know the exact tool you want
- you want the smallest possible change
- you are scripting one-tool install/check/apply flows

Examples:

- `bash`
- `oh-my-zsh`
- `fzf`

### Tags

Logical groupings defined in `manifests/tags.yaml`.

Use tags when:

- you want a functional slice like shell or core tools
- you want a reusable non-profile selection
- you are building a setup in layers

Current tags include:

- `app`
- `cli`
- `core`
- `git`
- `node`
- `shell`
- `terminal`
- `zsh`

### Profiles

Named saved selections defined in `manifests/profiles.yaml`.

Use profiles when:

- you want a repeatable named machine shape
- you want to share a curated setup across machines
- you want one command to expand to packages plus tags

Current repo profiles are empty by default:

```yaml
schema_version: 1
profiles: []
```

You can add profiles later as named combinations of packages and tags.

## Desired State

This project uses a hybrid desired-state model:

- repo manifests define available packages, tags, and profiles
- machine-local state stores the selection for one specific machine

Default state path:

```bash
${XDG_STATE_HOME:-$HOME/.local/state}/machine-setup/state.yaml
```

The interactive flow can save your chosen selection into this state file.

Typical contents:

```yaml
profile: work-laptop
packages:
  include:
    - oh-my-zsh
  exclude: []
tags:
  include:
    - shell
  exclude: []
```

Environment override:

```bash
export MACHINE_SETUP_STATE_PATH=/custom/path/state.yaml
```

How to think about desired state:

- repo manifests define what is available
- local state defines what this specific machine is supposed to have
- `status` compares that expected machine state with reality

If you want to identify missing packages on a new machine:

1. choose or save the desired selection with `./bin/setup`
2. run `./bin/setup status`

If you want to identify software installed on a machine but not represented in
the catalog, use the collector:

```bash
./scripts/collect_current_state.sh
```

## Configuration

Default config path:

```bash
${XDG_CONFIG_HOME:-$HOME/.config}/machine-setup/config.yaml
```

Supported config keys today:

```yaml
chezmoi:
  repo_url: https://example.com/your-dotfiles.git
  base_target: shell-base
```

Environment overrides:

```bash
export MACHINE_SETUP_CONFIG_PATH=/custom/path/config.yaml
export CHEZMOI_REPO_URL="https://example.com/your-dotfiles.git"
```

## Dry-Run Mode

Use `--dry-run` to preview mutating operations:

```bash
./bin/setup bootstrap --dry-run
./bin/setup install --tag shell --dry-run
./bin/setup apply-config --package oh-my-zsh --dry-run
./bin/setup install --group shell --dry-run --yes
```

Use dry-run when:

- you are testing a new selection
- you want to preview `chezmoi` bootstrap/apply behavior
- you are validating the repo on a new machine before making changes

## JSON Output

Structured JSON output is supported for:

- `list`
- `doctor`
- `status`
- `drift`
- `bootstrap`

Examples:

```bash
./bin/setup list --format json
./bin/setup status --format json
./bin/setup drift --format json --tag shell
./bin/setup bootstrap --format json
```

Use JSON output when:

- integrating the CLI into scripts or other tooling
- you want structured status or drift results
- text output is too human-oriented for your workflow

## Current Package Catalog

Current packages in the repo:

- `bash`
- `bat`
- `codex`
- `fzf`
- `fzf-extra`
- `gnu-sed`
- `nvm`
- `oh-my-zsh`
- `pre-commit`
- `task`
- `yq`
- `zsh-autosuggestions`
- `zsh-autosuggestions-plugin`
- `zsh-syntax-highlighting`
- `zsh-z`

Check the live catalog with:

```bash
./bin/setup list
```

## Validation and Tests

Run the full local validation suite:

```bash
./scripts/validate.sh
```

If `shellcheck` is not installed locally:

```bash
./scripts/validate.sh --skip-shellcheck
```

Current validation includes:

- manifest validation
- collect-ignore validation
- shell linting through `shellcheck`
- `bats` test suite

## Collect Current Machine State

Generate a report of installed software against the manifest catalog:

```bash
./scripts/collect_current_state.sh
```

The script writes a markdown report under `reports/`.

It uses:

- `manifests/collect-ignore.yaml`

Ignored items are suppressed from the manifest-aware installed and
missing-from-manifest sections.

Use this when:

- reviewing an existing machine to decide what belongs in the catalog
- finding installed tools that are not yet represented in manifests
- curating ignores for intentionally unmanaged tools

## Limitations

- officially scoped only for macOS Apple Silicon right now
- Linux support is not implemented yet
- package catalog is still curated and relatively small
- `install --group` is legacy compatibility behavior, not the long-term model
- this repo assumes your actual config is managed in a separate `chezmoi` repo

## Additional Docs

- usage examples: [docs/USAGE.md](/Users/gokul/Dev/machine-setup/docs/USAGE.md)
- project plan: [docs/PROJECT_PLAN.md](/Users/gokul/Dev/machine-setup/docs/PROJECT_PLAN.md)
- implementation tracker: [docs/IMPLEMENTATION_TASKS.md](/Users/gokul/Dev/machine-setup/docs/IMPLEMENTATION_TASKS.md)
- package inventory review: [docs/CURRENT_PACKAGE_INVENTORY.md](/Users/gokul/Dev/machine-setup/docs/CURRENT_PACKAGE_INVENTORY.md)
