# Adding Packages

1. Add a package entry in `manifests/packages.yaml` with:
- `id`
- `group`
- `manager`
- `check` (idempotency gate)
- `install`
- optional `depends_on`

2. Add the package `id` to the relevant group in `manifests/groups.yaml`.

3. For `shell_component`, add a case handler in `lib/compat/install.sh`.
   Do not add handlers that copy dotfiles into `$HOME`; config should be handled
   through `chezmoi`.

4. Validate with:

```bash
./bin/setup list
./bin/setup install --package <id> --dry-run --yes
```
