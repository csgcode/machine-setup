# Decisions

- Interface: interactive-first CLI with subcommands for automation.
- Data model: declarative YAML manifests for groups and packages.
- Idempotency: every package has a `check` command before install.
- Scope v1: `core` and `shell` groups only.
- Migration: preserve `./bin/setup`, but treat group-based install flows as
  legacy compatibility behavior during the redesign.
- Dotfiles: curated copy of reusable `.zshrc` defaults, excluding machine/project-specific entries.
- Safety: supports `--dry-run`; dotfile updates create `.setup.bak` backup.
