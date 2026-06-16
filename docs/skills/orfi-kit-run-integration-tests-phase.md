# orfi-kit-run-integration-tests-phase
> Run integration tests for one GSD phase (or all phases) and log a parsed pass/fail/skip summary.

## What it does
Runs `dotnet test` integration tests for a specified GSD phase, or for all phases when no phase number is given. It writes detailed test output to a log file, appends a per-project summary block after each test project finishes, and a grand-total block once all projects complete. Finally it opens a new terminal window that tails the log so you can watch progress live.

## When it fires / how to invoke
Invoke the slash command:
```
/orfi-kit-run-integration-tests-phase [PHASE_NUMBER]
```
Pass a phase number to scope the run to that GSD phase only. Omit it to run integration tests for ALL GSD phases.

## Prerequisites
- A `dotnet`-based (C#) project — the command runs `dotnet test`.
- A repo root where it can create a `.tests/` directory.
- For the live tail step, a terminal launcher: `gnome-terminal` on Linux, or PowerShell (`pwsh`) on Windows.

## Behavior / rules
- Log path is `.tests/integ-tests-log.log`, relative to the repo root. The `.tests/` directory is created if missing (`mkdir -p .tests`).
- The log is **overwritten** on every run (not appended) — each run starts clean.
- Every `dotnet test` invocation uses `--logger "console;verbosity=detailed"` so the pass/fail/skip summary is captured in the log.
- After EACH test project finishes, a summary block is appended to the log, parsed from actual test output:
  ```
  ============================================================
  PROJECT: <project name>
  TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
  ============================================================
  ```
- After ALL projects complete, a grand-total block is appended:
  ```
  ############################################################
  GRAND TOTAL: <n>  |  PASSED: <n>  |  FAILED: <n>  |  SKIPPED: <n>
  ############################################################
  ```
- These numbers are parsed from real test output — never guessed or estimated (NON-NEGOTIABLE).
- A new terminal window is opened to tail the log. The relative log path is resolved to an absolute path before being passed to the subprocess:
  - Linux: `gnome-terminal -- tail -f .tests/integ-tests-log.log`
  - Windows: `powershell.exe -Command "Start-Process pwsh -ArgumentList '-NoExit', '-Command', \"Get-Content '<ABSOLUTE_PATH_TO_REPO>/.tests/integ-tests-log.log' -Wait -Tail 50\""` — the absolute path is resolved from `pwd` before embedding.

## Notes
- Pairs with `orfi-kit-run-unit-tests-phase`, which runs unit tests for a GSD phase using the same phase-scoped pattern.
