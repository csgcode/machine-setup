# machine-setup

Idempotent macOS machine bootstrap for development tools.

## Quickstart

```bash
./bin/setup doctor
./bin/setup list
./bin/setup bootstrap
./bin/setup install --group core --yes
./bin/setup install --group shell --yes
```

## Features

- Interactive menu by default (`./bin/setup`)
- Group and single-package installs
- Explicit `chezmoi` bootstrap command
- Declarative package/group manifests (YAML)
- Dry-run mode
- JSON output for reporting commands
- Configuration is being migrated to `chezmoi`

See `docs/USAGE.md` for full command examples.

## Validation

Run the local validation suite with:

```bash
./scripts/validate.sh
```

If `shellcheck` is not installed locally, you can still run the rest with:

```bash
./scripts/validate.sh --skip-shellcheck
```
