Run shellcheck against all scripts in this package and report findings.

## Steps

1. Verify shellcheck is available: `which shellcheck`. If not found, tell the user to install it (`brew install shellcheck` on macOS, `apt install shellcheck` on Ubuntu) and stop.

2. Run shellcheck on every script:
```bash
shellcheck bin/wps bin/server-tools/*
```

3. Report all findings grouped by file. For each finding include: severity (error/warning/info), line number, the shellcheck code (SC####), and a plain-English explanation of the fix.

4. If there are errors (severity: error), flag them clearly — these must be fixed before merging.

5. Do not auto-fix. Report only; let the user decide what to act on.
