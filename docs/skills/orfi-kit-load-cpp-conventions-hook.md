# orfi-kit-load-cpp-conventions-hook

> Surfaces the repo's own C++ formatting and naming rules **before** a source or header is written, so the first draft is already compliant.

## What it does

This is a global `PreToolUse` hook on `Write` / `Edit` / `MultiEdit`. When the file being written is a C/C++ source or header, it reads the rules the target repo actually encodes and injects them into context *before* the edit happens:

- The **nearest `.clang-format`** (formatting, include order) — both clang config files resolve nearest-file-wins up the directory tree.
- The **nearest `.clang-tidy`**, with `readability-identifier-naming.*` keys **paired with their values**. `.clang-tidy` splits each option across a `- key:` line and a following `value:` line; printed apart, `ClassCase` tells you nothing, so the hook rejoins them into `ClassCase = CamelCase`.
- The enabled `Checks:` block and `WarningsAsErrors:` if set.
- Whether a `compile_commands.json` exists.

The problem it solves: conventions used to be consulted only at review time, so code got written blind to the repo's own config and fixed afterwards — or shipped and caught by CI. This moves the rules to write time.

## When it fires / how to invoke

Passive — it runs automatically. Matchers in `settings.json` match **tool names**, not file globs, so the hook is wired to `Write|Edit|MultiEdit` and does its own extension filtering from `.tool_input.file_path`: `*.cpp`, `*.hpp`, `*.h`, `*.cc`, `*.cxx`, `*.inl`. Anything else exits 0 silently. You never invoke it directly.

## Prerequisites

None. `jq` is used when present and `sed` is the fallback, so no external tool is required. Vendored paths (`third_party/`, `external/`, `vendor/`) and generated files (`ui_*.h`, `moc_*.cpp`, `qrc_*.cpp`) are skipped — they follow their upstream's conventions, not yours.

## Behavior / rules

- **The repo under review always wins.** When the repo encodes rules, the hook reports only those and imports no external style guide.
- **Most C++ repos ship neither config. That is the common case and not an error** — and it is exactly when the kit's own baseline takes over. With no `.clang-format` and no `.clang-tidy`, the hook reads the baseline out of the code-review skill's `CONFIG.md` and enforces it as the contract, stating that deviation is a violation including in pre-existing code you touch. The baseline is read from disk rather than duplicated in the hook, so it cannot drift from the `CONFIG.md` that documents it.

  Precedence is unchanged: **the repo always wins.** This only fires when there is nothing to win against. And it is honest about its limit — with no config in the repo, `clang-format` and `clang-tidy` have nothing to read, so the baseline is enforced by applying it, not by a tool. Adopting it as the repo's own config is what makes it enforceable by the build and CI.

- If the baseline is not installed either, nothing is enforceable: the hook defers to the prevailing pattern of the file and its immediate siblings, and never imports an external C++ style guide.
- **Read-only.** The hook never writes config into your repo.
- **`clang-tidy` is largely inert without `compile_commands.json`** — it cannot resolve includes. The hook detects the database (in the tree or in a `build/`, `out/`, `cmake-build-*` dir) and, when it is missing, says the naming rules will **not** be mechanically enforced and must be applied by reading. Generating a compilation database is a build action, not this hook's job.
- If `.clang-tidy` enables `cppcoreguidelines-owning-memory`, the hook reports that the repo has **encoded a smart-pointer ownership policy**, so raw owning pointers are a real violation. Otherwise it says nothing about pointer style.
- **No tool enforces filenames** — `clang-tidy` covers identifiers only. Filename conventions are reported as advisory, and the hook explicitly warns against bulk renames: a rename breaks every `#include` of the old name.
- **Advisory: it never blocks a write.** Exit is always 0.
- Output is capped (`ORFI_CONVENTIONS_MAX_LINES`, default 120).

## Example

Editing a header in a repo that ships both configs but no compilation database:

```
[ORFI C++ CONVENTIONS — the repo's own rules for widget.hpp]

--- /path/to/.clang-format (formatting, include order)
BasedOnStyle: LLVM
IndentWidth: 4
ColumnLimit: 100

--- /path/to/.clang-tidy (naming, static analysis)
  Identifier naming (readability-identifier-naming.*):
    ClassCase = CamelCase
    PrivateMemberPrefix = m_

  WarningsAsErrors: 'readability-identifier-naming,bugprone-*'
  => Those checks FAIL the build. Not nits.

  cppcoreguidelines-owning-memory is ENABLED: this repo has encoded a
  smart-pointer ownership policy. Raw owning pointers are a real violation.

  !! No compile_commands.json found. clang-tidy cannot resolve includes
     without it and is largely INERT, so the naming rules above will NOT be
     mechanically enforced on this edit — you must apply them by reading.
```

And in a repo with no config at all — the common case, where the kit baseline takes over:

```
[ORFI C++ CONVENTIONS — thing.cpp]
This repo encodes NOTHING: no .clang-format, no .clang-tidy. That is the common
case in C++ and not an error.

ENFORCING the orfi-kit baseline as the contract for this repo. These are the
kit's house-style defaults, from ~/.claude/skills/orfi-kit-cpp-code-review/CONFIG.md.
Deviation is a violation and should be reported as one, including in
pre-existing code you touch. Write this file to the rules below.

  --- baseline .clang-format
  BasedOnStyle: LLVM
  IndentWidth: 4
  ColumnLimit: 120
  BreakBeforeBraces: Allman
  ...

  --- baseline .clang-tidy (naming keys paired with their values)
    ClassCase = CamelCase
    FunctionCase = camelBack
    PrivateMemberPrefix = 'm_'
    ClassMemberPrefix = 's_'
    ConstantCase = UPPER_CASE
    ...

NOTE: with no config in the repo, clang-format and clang-tidy have nothing to
read — the baseline is enforced by you applying it, not by a tool.
```

## Notes

- Pairs with `orfi-kit-verify-cpp-format-hook`, which checks the file *after* it is written.
- On Copilot the same rule text loads via the guardrails extension (`onSessionStart`), and written
  files are verified by the native `PostToolUse` hooks (`~/.copilot/hooks/orfi-kit.json`); this
  loader itself is not registered there because the extension already serves the rules at session
  start. OpenCode gets the rules at chat start via the plugin (`chat.system.transform`). See the
  README.
- The rule text is duplicated between this hook and `extension.mjs` on purpose (different platforms, no shared code). **Change them together.**
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
