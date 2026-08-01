# orfi-kit-verify-cpp-format-hook

> Runs `clang-format --dry-run --Werror` (and `clang-tidy`, when a compilation database exists) on a C/C++ file **right after** it is written.

## What it does

This is a global `PostToolUse` hook on `Write` / `Edit` / `MultiEdit`. When the file just written is a C/C++ source or header, it runs the enforcers the repo has actually configured:

- **`clang-format --dry-run --Werror --style=file`** — only when the repo ships a `.clang-format`. Reports what differs without touching the file.
- **`clang-tidy -p <build dir> --quiet`** — only when both a `.clang-tidy` *and* a `compile_commands.json` exist.

Together with `orfi-kit-load-cpp-conventions-hook` this closes the loop: the loader states the rules before the write, the verifier confirms the result after it — so nothing is deferred to review or CI.

## When it fires / how to invoke

Passive — it runs automatically after a successful write. Matchers match **tool names**, not file globs, so the hook is wired to `Write|Edit|MultiEdit` and filters extensions itself from `.tool_input.file_path`: `*.cpp`, `*.hpp`, `*.h`, `*.cc`, `*.cxx`, `*.inl`. You never invoke it directly.

## Prerequisites

None are required, and every absence is reported rather than silently skipped:

- No `clang-format` on PATH (but a `.clang-format` exists) → stderr note, exit 0.
- No `clang-tidy` on PATH (but a `.clang-tidy` exists) → stderr note, exit 0.
- No `compile_commands.json` → stderr note saying **naming was not checked**, exit 0.
- No config at all → silent, nothing is enforceable.

`jq` is used when present, `sed` is the fallback. Vendored paths (`third_party/`, `external/`, `vendor/`) and generated files (`ui_*.h`, `moc_*.cpp`, `qrc_*.cpp`) are skipped.

## Behavior / rules

- **Advisory: it reports, it does not block.** Exit is 0 even when violations are found.

  Why advisory rather than blocking: a `PostToolUse` hook fires on *every* edit, so a multi-file change gets verified while it is still half-written, and pre-existing drift in the same file reports against an author who never touched it. That is especially true in C++, where most repos have no config at all and formatting drift is the norm. The trade-off is that a violation can be ignored — which is why the loader hook runs first.

  Set `ORFI_CPP_FORMAT_BLOCKING=1` to make it exit 2 (block) instead. Opt-in.

- **The exit code is captured from the bare invocation, never through a pipe.** `clang-format … | tail` makes `$?` the status of `tail`, which always succeeds, so a real violation silently reads as clean. Both tools redirect to a temp file and assign `$?` on the very next line, then filter for display. Verified with a stand-in binary: bare `$?=1`, piped `$?=0`.

- **`clang-format` runs only when the repo ships a `.clang-format`.** Without one it would fall back to a built-in style the repo never agreed to, and reporting against that is inventing a rule.

- **`clang-tidy` runs only when a `compile_commands.json` exists.** Per the C++ review skill's `CONFIG.md`, it is largely inert without one — it cannot resolve includes and its output is unreliable. When the database is missing the hook says naming **was not checked** and that this is *unverified, not clean*.

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

- On a clean file the hook stays **silent** on stdout; any "could not verify" note goes to stderr.
- Claude-Code-only. See Notes.

## Example

After writing a header that doesn't match the repo's `.clang-format`:

```
[ORFI C++ FORMAT] clang-format reports violations in widget.hpp (exit 1).
Config: /path/to/.clang-format

widget.hpp:1:1: warning: code should be clang-formatted [-Wclang-format-violations]

These are this repo's own .clang-format / .clang-tidy rules, not general C++
habit. Fix them now — leaving them turns a write-time fix into a review or CI
failure, and under WarningsAsErrors a naming hit is a build break.
```

When the tools are not installed (stderr, exit 0 — never a silent pass):

```
orfi-kit-verify-cpp-format: clang-format not on PATH — formatting not verified for widget.hpp (config exists at /path/to/.clang-format).
orfi-kit-verify-cpp-format: clang-tidy not on PATH — naming not verified for widget.hpp (config exists at /path/to/.clang-tidy).
```

When there is a `.clang-tidy` but no compilation database:

```
orfi-kit-verify-cpp-format: no compile_commands.json — clang-tidy is inert without a
compilation database, so NAMING WAS NOT CHECKED for widget.hpp. This is unverified,
not clean. (CMake: CMAKE_EXPORT_COMPILE_COMMANDS=ON; qmake: use bear.)
```

## Notes

- **There is no Copilot equivalent, by platform limitation.** The Copilot SDK exposes only `onSessionStart` and `onUserPromptSubmitted` — no per-edit event and no post-response event — so Copilot can *load* conventions but cannot *verify* an edit. This mirrors the brevity asymmetry already documented in `extension.mjs`: Claude gates, Copilot nudges.
- Pairs with `orfi-kit-load-cpp-conventions-hook`.
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
