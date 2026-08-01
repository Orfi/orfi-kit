# orfi-kit-verify-csharp-format-hook

> Runs `dotnet format --verify-no-changes` on a `.cs` file **right after** it is written, and reports any violation against the repo's own rules.

## What it does

This is a global `PostToolUse` hook on `Write` / `Edit` / `MultiEdit`. When the file just written is a `.cs` file, it finds the containing project and runs the same verifier CI would:

```bash
dotnet format <project>.csproj --verify-no-changes --include <relative path> --verbosity quiet
```

Violations are reported with the exact file, line, and column. Together with `orfi-kit-load-csharp-conventions-hook` this closes the loop: the loader states the rules before the write, the verifier confirms the result after it — so nothing is deferred to review or CI.

## When it fires / how to invoke

Passive — it runs automatically after a successful write. Matchers match **tool names**, not file globs, so the hook is wired to `Write|Edit|MultiEdit` and does its own `*.cs` filtering from `.tool_input.file_path`. You never invoke it directly.

## Prerequisites

- The .NET SDK (`dotnet`) on PATH. If it is missing, the hook says so on **stderr** and exits 0 — it never pretends the file was verified.
- A `.csproj` above the file, used as the MSBuild anchor. If none is found, same graceful bail with a message.

`jq` is used when present, `sed` is the fallback.

## Behavior / rules

- **Advisory: it reports, it does not block.** Exit is 0 even when violations are found.

  Why advisory rather than blocking: a `PostToolUse` hook fires on *every* edit, so a multi-file change gets verified while it is still half-written, and any pre-existing debt in the same project reports against an author who never touched it. Blocking on that would make every edit hostage to unrelated violations. The trade-off is that a violation can be ignored — which is why the loader hook runs first, so compliance is the default rather than a correction.

  Set `ORFI_CSHARP_FORMAT_BLOCKING=1` to make it exit 2 (block) instead. Opt-in.

- **The exit code is captured from the bare invocation, never through a pipe.** `dotnet format … | tail` makes `$?` the status of `tail`, which always succeeds, so a real violation silently reads as clean. The hook redirects to a temp file, assigns `$?` on the very next line, and only then filters for display. Verified on a real violating file: bare `$?=2`, piped `$?=0`.

- **`--include` is given a path relative to the project**, and the command runs from the project directory. An absolute path is accepted by `dotnet format` and then matches nothing: it analyses zero files and exits 0 — a false clean. Verified on the same violating file: `$?=2` with a relative path, `$?=0` with either `/c/...` or `C:\...`. Scoping to one file also keeps a large project from being re-verified on every keystroke.

- **Findings are delivered, not just printed.** The hook emits
  `hookSpecificOutput.additionalContext`, which the harness defines as *non-error feedback delivered
  to the model so it can act on it*, and also writes a human-readable copy to stderr so you can see
  the check ran.

  This matters because an earlier version only printed to stdout. On `exit 0`, plain stdout goes to
  the transcript — so the hook found real violations and effectively swallowed them. That is the
  "wired but enforces nothing" failure the README warns about: advisory must not mean invisible. The
  edit still is not blocked, but the violations now have to be dealt with rather than ignored.

  The JSON is built with `jq` when present and hand-escaped otherwise, so a missing tool is never
  why a finding goes undelivered. Verified on both paths with Windows paths and embedded quotes in
  the payload.

- Generated files (`*.g.cs`, `*.designer.cs`, `*.generated.cs`) and `Migrations/` are skipped.
- On a clean file the hook stays **silent** — a hook that congratulates every edit is noise.
- Claude-Code-only. See Notes.

## Example

After writing a `.cs` file with bad whitespace:

```
[ORFI C# FORMAT] dotnet format reports violations in Bad.cs (exit 2).
Project: /path/to/App.csproj

Bad.cs(1,15): error WHITESPACE: Fix whitespace formatting. Replace 1 characters with '\r\n\r\n'.
Bad.cs(2,17): error WHITESPACE: Fix whitespace formatting. Replace 1 characters with '\r\n'.
Bad.cs(3,27): error WHITESPACE: Fix whitespace formatting. Insert '\s'.

These are this repo's own .editorconfig / analyzer rules, not general C# habit.
Fix them now — under TreatWarningsAsErrors they are a build break, and leaving
them turns a write-time fix into a review or CI failure.
```

And when the toolchain is absent (stderr, exit 0):

```
orfi-kit-verify-csharp-format: dotnet not on PATH — format not verified for Bad.cs.
```

## Notes

- **There is no Copilot equivalent, by platform limitation.** The Copilot SDK exposes only `onSessionStart` and `onUserPromptSubmitted` — no per-edit event and no post-response event — so Copilot can *load* conventions but cannot *verify* an edit. This mirrors the brevity asymmetry already documented in `extension.mjs`: Claude gates, Copilot nudges.
- Pairs with `orfi-kit-load-csharp-conventions-hook`.
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
