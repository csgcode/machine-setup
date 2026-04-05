# Current Package Inventory

## Purpose

This document captures software detected on the current Apple Silicon Mac to
help decide the initial desired-state catalog for this repository.

It is a review document, not a final manifest.

Captured on: 2026-04-04

## Recommended Scope For Initial Catalog Review

Recommended to keep in scope first:

- Homebrew leaves
- Homebrew casks
- selected global developer tools if clearly relevant

Recommended to defer for now:

- App Store applications
- random `.app` bundle scanning
- removal/uninstall planning
- secrets and password manager automation

## Detected Homebrew Leaves

These are top-level formulae/taps rather than every transitive dependency.

- awscli
- bash
- bat
- chezmoi
- fzf
- gdk-pixbuf
- glab
- gnu-sed
- libffi
- libmagic
- nvm
- pango
- pchuri/tap/confluence-cli
- pipx
- postgresql@17
- pre-commit
- redis
- task
- tmux
- yq
- zsh-autocomplete
- zsh-autosuggestions

## Detected Homebrew Casks

- aerospace
- codex
- maccy
- meetingbar
- session-manager-plugin

## Detected Global Node Packages

The current environment only reported:

- npm

No broader global Node package set was detected from the command output.

## Additional Installed Formulae Observed

These were present in `brew list --formula` but many are likely dependencies
rather than intentional desired-state entries.

- node
- pipx
- postgresql@17
- python@3.13
- python@3.14
- redis
- ripgrep
- tmux

Do not automatically treat transitive formulae as desired-state selections.

## Partial / Unreliable Signals

### Brew Services

`brew services list` did not return normal service state in this environment and
reported an execution limitation under `tmux`, so service status should be
re-checked manually during implementation.

### Cargo

`cargo` was not available in this environment, so no Rust global package
inventory was captured.

### Pipx

`pipx list` could not complete in this environment because its logging path
write was blocked. If pipx-managed applications matter for the desired-state
catalog, re-check this manually outside the current sandbox.

## Suggested Initial Candidate Catalog

These look like reasonable candidates for early review because they appear to be
intentional user-facing tools rather than transitive dependencies.

### CLI Tools

- awscli
- bash
- bat
- chezmoi
- fzf
- glab
- gnu-sed
- nvm
- pipx
- postgresql@17
- pre-commit
- redis
- task
- tmux
- yq
- zsh-autocomplete
- zsh-autosuggestions

### GUI Apps

- aerospace
- codex
- maccy
- meetingbar
- session-manager-plugin

### Needs Review Before Inclusion

- gdk-pixbuf
- libffi
- libmagic
- pango
- pchuri/tap/confluence-cli

These may be intentional, but they need confirmation before being promoted into
the desired-state manifest.

## Proposed Review Outcome Format

When converting this document into manifests, classify each item as one of:

- keep: should be part of desired state
- maybe: useful but not core yet
- skip: installed on this machine but should not be managed here

Optional tag ideas for later:

- `core`
- `shell`
- `work`
- `personal`
- `database`
- `terminal`
- `cli`
- `gui`

## Next Review Step

Review the detected packages and decide:

- which packages belong in phase 1
- which tags each package should carry
- which packages should have linked `chezmoi` config targets
