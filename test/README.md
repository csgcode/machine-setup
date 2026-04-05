# Test Suite

This repository uses `bats-core` for shell tests.

Run locally:

```bash
bats test
./scripts/validate.sh
```

Current phase-0 coverage focuses on:

- CLI usage and argument parsing
- manifest helper behavior
- dry-run command behavior
- duplicate dependency suppression
- circular dependency detection

Phase-1 coverage now also includes:

- package/tag selection resolution
- execution planning
- desired-state config/state reads and writes
- `chezmoi` bootstrap, init, apply, and diff behavior with stubbed commands
- direct command workflows for `install`, `check`, and `apply-config`
- profile-based command workflows on the same backend as package/tag selection
- config drift reporting across clean, drifted, unavailable, and
  not-applicable states
- desired-state reporting from merged profile and local overrides
- JSON output coverage for `list`, `doctor`, `status`, and `drift`
- guided interactive workflows, including success and abort paths
