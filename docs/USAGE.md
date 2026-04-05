# Usage

## Interactive (default)

```bash
./bin/setup
```

The default flow is a guided prompt sequence:

- choose `install`, `check`, or `apply-config`
- choose packages, tags, or profiles
- review the resolved package set before execution
- optionally save the selection into local machine state after install/config

## List known packages

```bash
./bin/setup list
```

## Doctor

```bash
./bin/setup doctor
```

## Report desired-state status

```bash
./bin/setup status
./bin/setup status --format json
```

`list`, `doctor`, `status`, and `drift` also support `--format json` for
machine-readable output.

## Install one group

Legacy compatibility path during migration:

```bash
./bin/setup install --group core
./bin/setup install --group shell
```

## Install one package

```bash
./bin/setup install --package oh-my-zsh
./bin/setup install --package oh-my-zsh --package zsh-z
```

## Install by tag

```bash
./bin/setup install --tag shell
./bin/setup install --package oh-my-zsh --tag shell
```

## Install by profile

```bash
./bin/setup install --profile work-laptop
```

## Check selected packages

```bash
./bin/setup check --package oh-my-zsh
./bin/setup check --tag shell
./bin/setup check --profile work-laptop
```

## Apply config for selected packages

```bash
./bin/setup apply-config --package oh-my-zsh
./bin/setup apply-config --tag shell
./bin/setup apply-config --profile work-laptop
```

## Report config drift for selected packages

```bash
./bin/setup drift --package oh-my-zsh
./bin/setup drift --tag shell
./bin/setup drift --profile work-laptop
./bin/setup drift --tag shell --format json
```

Shell configuration is no longer copied into `$HOME` by this repo. Dotfiles are
intended to be managed through `chezmoi`.

## Dry-run

```bash
./bin/setup install --package oh-my-zsh --dry-run
./bin/setup apply-config --tag shell --dry-run
./bin/setup install --group shell --dry-run --yes
```
