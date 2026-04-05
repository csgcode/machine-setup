# machine-setup

Idempotent macOS machine bootstrap for development tools.

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
- Dry-run mode
- JSON output for reporting commands
- Configuration is being migrated to `chezmoi`

See `docs/USAGE.md` for full command examples.
