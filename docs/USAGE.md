# Usage

## Interactive (default)

```bash
./bin/setup
```

## List known packages

```bash
./bin/setup list
```

## Doctor

```bash
./bin/setup doctor
```

## Install one group

Legacy compatibility path during migration:

```bash
./bin/setup install --group core
./bin/setup install --group shell
```

## Install one package

```bash
./bin/setup install --package oh-my-zsh
```

Shell configuration is no longer copied into `$HOME` by this repo. Dotfiles are
intended to be managed through `chezmoi`.

## Dry-run

```bash
./bin/setup install --group shell --dry-run --yes
```
