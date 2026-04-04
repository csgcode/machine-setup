# Decisions

- Interface: interactive-first CLI with package/tag subcommands for automation.
- Data model: declarative YAML manifests for groups and packages.
- Idempotency: every package has a `check` command before install.
- Scope v1: `core` and `shell` groups only.
- Migration: preserve `./bin/setup`, but treat group-based install flows as
  legacy compatibility behavior during the redesign.
- Command model: `install`, `check`, and `apply-config` on package/tag
  selections are the primary direct interface.
- Dotfiles: this repo should not copy dotfiles into `$HOME`; configuration is
  moving to `chezmoi`.
- Safety: supports `--dry-run`; install flows should avoid direct home-directory
  config writes.
