# Common Workflows

This document is the practical operator guide for maintaining this repository.

Use it when you need to:

- add a new package or application
- remove a managed package
- add a tag
- add a profile
- audit unmanaged software on a machine
- save `chezmoi` drift back into source
- validate changes before committing

## Files To Know

Main files involved in day-to-day maintenance:

- [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml)
- [tags.yaml](/Users/gokul/Dev/machine-setup/manifests/tags.yaml)
- [profiles.yaml](/Users/gokul/Dev/machine-setup/manifests/profiles.yaml)
- [groups.yaml](/Users/gokul/Dev/machine-setup/manifests/groups.yaml)
- [ADDING_PACKAGES.md](/Users/gokul/Dev/machine-setup/docs/maintainers/ADDING_PACKAGES.md)
- [README.md](/Users/gokul/Dev/machine-setup/README.md)

Only edit [groups.yaml](/Users/gokul/Dev/machine-setup/manifests/groups.yaml) if you still want the legacy `install --group` compatibility path to include the package.

## 1. Add A New Application Or Package

For most additions, the main file is [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml).

You usually edit:

- [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml)
- [tags.yaml](/Users/gokul/Dev/machine-setup/manifests/tags.yaml), only if a new tag is needed
- [groups.yaml](/Users/gokul/Dev/machine-setup/manifests/groups.yaml), only for legacy group support

### Example: Add a Homebrew formula

Add a package entry like this:

```yaml
  - id: ripgrep
    name: ripgrep
    group: core
    platform:
      - macos
    tags:
      - core
      - cli
    installer:
      kind: brew_formula
      package: ripgrep
    check:
      command: command -v rg >/dev/null 2>&1
    depends_on: []
```

Validate it:

```bash
./bin/setup list
./bin/setup install --package ripgrep --dry-run --yes
./scripts/validate.sh --skip-shellcheck
```

### Example: Add a Homebrew cask application

Add a package entry like this:

```yaml
  - id: wezterm
    name: WezTerm
    group: core
    platform:
      - macos
    tags:
      - app
      - terminal
    installer:
      kind: brew_cask
      package: wezterm
    check:
      command: brew list --cask wezterm >/dev/null 2>&1
    depends_on: []
```

Validate it:

```bash
./bin/setup install --package wezterm --dry-run --yes
```

### Example: Add a package with `chezmoi`-managed config

If the package should also trigger config apply, add a `config` block:

```yaml
  - id: starship
    name: starship
    group: shell
    platform:
      - macos
    tags:
      - shell
      - terminal
      - cli
    installer:
      kind: brew_formula
      package: starship
    check:
      command: command -v starship >/dev/null 2>&1
    depends_on: []
    config:
      target: shell/starship
      strategy: chezmoi_target
      optional: true
```

Then validate both install and config flow:

```bash
./bin/setup install --package starship --dry-run --yes
./bin/setup apply-config --package starship --dry-run --yes
```

### If the package uses `shell_component`

For `shell_component`, you must also add or update the handler in:

- [shell.sh](/Users/gokul/Dev/machine-setup/lib/installers/shell.sh)

The convention is:

- `installer.package: font-hack`
- installer function: `install_font_hack`

Do not add logic that copies dotfiles into `$HOME`. Config belongs in `chezmoi`.

Example:

```yaml
  - id: font-hack
    name: Hack font
    group: shell
    platform:
      - macos
    tags:
      - shell
      - terminal
      - fonts
    installer:
      kind: shell_component
      package: font-hack
    check:
      command: test -f "$HOME/Library/Fonts/Hack-Regular.ttf" || test -f "/Library/Fonts/Hack-Regular.ttf"
    depends_on: []
```

## 2. Remove A Managed Application Or Package

Edit:

- [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml)
- optionally [groups.yaml](/Users/gokul/Dev/machine-setup/manifests/groups.yaml)
- optionally [profiles.yaml](/Users/gokul/Dev/machine-setup/manifests/profiles.yaml) if a profile references it

Steps:

1. Remove the package entry from [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml)
2. Remove the package from any legacy group entry in [groups.yaml](/Users/gokul/Dev/machine-setup/manifests/groups.yaml)
3. Remove the package from any repo profile in [profiles.yaml](/Users/gokul/Dev/machine-setup/manifests/profiles.yaml)
4. Run validation

Validate:

```bash
./bin/setup list
./scripts/validate.sh --skip-shellcheck
```

This removes it from management. It does not uninstall the software from the machine.

## 3. Add A New Tag

Edit:

- [tags.yaml](/Users/gokul/Dev/machine-setup/manifests/tags.yaml)
- then update package entries in [packages.yaml](/Users/gokul/Dev/machine-setup/manifests/packages.yaml)

Example:

```yaml
  - id: python
    description: Python development tooling.
```

Then add it to packages:

```yaml
    tags:
      - core
      - cli
      - python
```

Validate:

```bash
./bin/setup install --tag python --dry-run --yes
./scripts/validate.sh --skip-shellcheck
```

## 4. Add A New Profile

Edit:

- [profiles.yaml](/Users/gokul/Dev/machine-setup/manifests/profiles.yaml)

Example:

```yaml
schema_version: 1

profiles:
  - id: work-laptop
    packages:
      - codex
      - pre-commit
    tags:
      - core
      - shell
      - git
```

Validate:

```bash
./bin/setup install --profile work-laptop --dry-run --yes
./bin/setup check --profile work-laptop
./scripts/validate.sh --skip-shellcheck
```

## 5. Find Software Installed On A Machine But Not Managed Here

Run:

```bash
./scripts/collect_current_state.sh
```

This writes a report into `reports/`.

The important sections are:

- `Installed brew formulae missing from manifest`
- `Installed brew casks missing from manifest`
- `Installed npm globals missing from manifest`

Use this when auditing an existing machine and deciding what should be added to the catalog.

If there is known noise, edit:

- [collect-ignore.yaml](/Users/gokul/Dev/machine-setup/manifests/collect-ignore.yaml)

## 6. Find Packages Missing On A New Machine

Use:

```bash
./bin/setup status
```

This compares saved desired state with what is actually installed.

Use it after:

- selecting software through `./bin/setup`
- or saving a desired profile/tags/packages into local state

Important distinction:

- `status` answers: what should be installed here, but is missing
- `collect_current_state.sh` answers: what is installed here, but not represented in the catalog

## 7. Save `chezmoi` Drift Back Into Source

Inspect drift:

```bash
chezmoi status
chezmoi diff
```

Save a local file back into `chezmoi` source:

```bash
chezmoi add ~/.zshrc
```

Then review and commit in the `chezmoi` repo:

```bash
cd ~/.local/share/chezmoi
git status
git diff
git add .
git commit -m "Update zshrc"
```

Use this only when you intentionally want local changes to become the new source of truth.

## 8. Remove Something Accidentally Added To `chezmoi`

If it is only untracked in the `chezmoi` source repo, delete it from the source repo:

```bash
rm -rf ~/.local/share/chezmoi/Dev
```

Then verify:

```bash
cd ~/.local/share/chezmoi
git status --short
```

If it was already committed in the `chezmoi` repo:

```bash
cd ~/.local/share/chezmoi
git rm -r Dev
git commit -m "Remove accidental Dev directory"
```

## 9. Validate Before Committing

Minimum validation:

```bash
./bin/setup list
./scripts/validate.sh --skip-shellcheck
```

Recommended targeted dry-run:

```bash
./bin/setup install --package <id> --dry-run --yes
./bin/setup apply-config --package <id> --dry-run --yes
```

Examples:

```bash
./bin/setup install --package wezterm --dry-run --yes
./bin/setup install --tag shell --dry-run --yes
./bin/setup install --profile work-laptop --dry-run --yes
```

## 10. Rules Of Thumb

- add packages atomically
- use tags for stable categories, not one-off selections
- use profiles for named machine shapes
- keep config in `chezmoi`, not in this repo
- avoid introducing shell logic unless manifests cannot express the case
- keep `check.command` reliable, because it is the idempotency gate
