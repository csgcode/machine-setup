# machine-setup

Idempotent macOS machine bootstrap for development tools and shell configuration.

## Quickstart

```bash
./bin/setup doctor
./bin/setup list
./bin/setup install --group core --yes
./bin/setup install --group shell --yes
```

## Features

- Interactive menu by default (`./bin/setup`)
- Group and single-package installs
- Declarative package/group manifests (YAML)
- Curated zsh dotfile application with backups
- Dry-run mode

See `docs/USAGE.md` for full command examples.
