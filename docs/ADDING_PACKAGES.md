# Adding Packages

1. Add a package entry in `manifests/packages.yaml` with:
- `id`
- `name`
- `group`
- `platform`
- `tags`
- `installer.kind`
- `installer.package`
- `check.command` (idempotency gate)
- optional `depends_on`
- optional `config`
- optional `notes`, `manual_steps`, `links`

2. Add any new tag definitions to `manifests/tags.yaml`.

3. Add the package `id` to the relevant group in `manifests/groups.yaml` while
   legacy group compatibility remains in place.

4. For `shell_component`, add a case handler in `lib/compat/install.sh`.
   Do not add handlers that copy dotfiles into `$HOME`; config should be handled
   through `chezmoi`.

5. Validate with:

```bash
./bin/setup list
./bin/setup install --package <id> --dry-run --yes
bash -lc 'source ./lib/manifest.sh && validate_manifest_schema'
```
