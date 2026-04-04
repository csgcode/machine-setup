# Test Suite

This repository uses `bats-core` for shell tests.

Run locally:

```bash
bats test
```

Current phase-0 coverage focuses on:

- CLI usage and argument parsing
- manifest helper behavior
- dry-run command behavior
- duplicate dependency suppression
- circular dependency detection
