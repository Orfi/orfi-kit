# orfi-kit-run-unit-tests-phase

> Run unit tests for one GSD phase (or all phases) and capture a parsed pass/fail/skip summary to a log.

## What it does

Runs your .NET unit tests via `dotnet test` for a given GSD phase, or for all phases when no phase number is supplied. It writes detailed test output to `.tests/unit-tests-log.log`, appends a per-project summary block after each test project finishes and a grand-total block after all projects complete, then opens a new terminal that tails the log live.

## When it fires / how to invoke

Run the slash command:

```
/orfi-kit-run-unit-tests-phase
```

Pass a phase number as the argument to scope the run to a single GSD phase. With no argument, it runs unit tests for ALL GSD phases.

## Prerequisites

- A .NET project using `dotnet test` (the command relies on `dotnet test` and its `--logger "console;verbosity=detailed"` option).
- A terminal launcher matching your OS for the live tail: `gnome-terminal` on Linux, or `pwsh`/`powershell.exe` on Windows.

## Behavior / rules

- Log path is `.tests/unit-tests-log.log`, relative to the repo root. The `.tests/` directory is created if it does not exist (`mkdir -p .tests`).
- Scope: with a phase number, only that GSD phase's unit tests run; without one, all phases run.
- The log is **overwritten** on every run (never appended) so each run starts clean.
- Every `dotnet test` invocation uses `--logger "console;verbosity=detailed"` so the pass/fail/skip summary is captured in the log.
- After each test project finishes, a summary block is appended to the log:

  ```
  ============================================================
  PROJECT: <project name>
  TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
  ============================================================
  ```

- After all projects complete, a grand-total block is appended:

  ```
  ############################################################
  GRAND TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
  ############################################################
  ```

- All numbers are parsed from the actual test output — never guessed or estimated.
- A new terminal window is opened to tail the log. The relative log path is resolved to an absolute path before being passed to the subprocess:
  - Linux: `gnome-terminal -- tail -f .tests/unit-tests-log.log`
  - Windows: `powershell.exe -Command "Start-Process pwsh -ArgumentList '-NoExit', '-Command', \"Get-Content '<ABSOLUTE_PATH_TO_REPO>/.tests/unit-tests-log.log' -Wait -Tail 50\""` (absolute path resolved from `pwd`).

## Notes

- Pairs with `orfi-kit-run-integration-tests-phase`, the integration-test counterpart that runs tests for a GSD phase or all phases.
