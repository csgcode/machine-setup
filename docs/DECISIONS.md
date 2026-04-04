# Decisions

- Interface: interactive-first CLI with subcommands for automation.
- Data model: declarative YAML manifests for groups and packages.
- Idempotency: every package has a `check` command before install.
- Scope v1: `core` and `shell` groups only.
- Migration: preserve `./bin/setup`, but treat group-based install flows as
  legacy compatibility behavior during the redesign.
- Dotfiles: this repo should not copy dotfiles into `$HOME`; configuration is
  moving to `chezmoi`.
- Safety: supports `--dry-run`; install flows should avoid direct home-directory
  config writes.
