---
name: orfi-kit-run-integration-tests-phase
description: Run integration tests for a GSD phase, or all phases if no number given.
---

PHASE_NUMBER: $ARGUMENTS

## Set log path

Log file path: `.tests/integ-tests-log.log` (relative to repo root).

Create the `.tests/` directory if it doesn't exist (`mkdir -p .tests`).

## Determine scope

If PHASE_NUMBER is provided, run integration tests for that GSD phase only.
If PHASE_NUMBER is not provided, run integration tests for ALL GSD phases.

## Run tests

**Overwrite** the log file (do not append). Each run starts with a clean log.

Use `--logger "console;verbosity=detailed"` on every `dotnet test` invocation so that the pass/fail/skip summary is captured in the log file.

## Summary blocks (NON-NEGOTIABLE)

After EACH test project finishes, parse the actual test output and append a summary block to the log:
```
============================================================
PROJECT: <project name>
TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
============================================================
```

After ALL projects complete, append a grand total:
```
############################################################
GRAND TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
############################################################
```

Parse these numbers from the actual test output. Do NOT guess or estimate.

## Tail log in new terminal

Open a new terminal window that tails the log file. Resolve the relative path to an absolute path before passing to the subprocess:
- Linux: `gnome-terminal -- tail -f .tests/integ-tests-log.log`
- Windows: `powershell.exe -Command "Start-Process pwsh -ArgumentList '-NoExit', '-Command', \"Get-Content '<ABSOLUTE_PATH_TO_REPO>/.tests/integ-tests-log.log' -Wait -Tail 50\""` — resolve the absolute path from `pwd` before embedding.