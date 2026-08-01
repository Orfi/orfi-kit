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

- **The repo under review always wins.** The hook reports only what the target repo encodes and imports no external style guide.
- **Most C++ repos ship neither config. That is the common case and not an error.** When both are absent the hook says so and tells you to follow the prevailing pattern of the file being edited and its immediate siblings — because with nothing encoded, that is the only honest standard.
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

And in a repo with no config at all — the common case:

```
[ORFI C++ CONVENTIONS] No .clang-format or .clang-tidy found above SP_Thing.cpp.
That is the common case in C++ and not an error — but it means nothing in this
repo encodes formatting or naming, so no rule here is enforceable.
Follow the prevailing pattern of THIS file and its immediate siblings, and say
that is what you did. Do not import a general C++ style guide.
```

## Notes

- Pairs with `orfi-kit-verify-cpp-format-hook`, which checks the file *after* it is written.
- The Copilot side loads the same rule text via the guardrails extension (`onSessionStart`), but has **no verifier** — that SDK exposes no per-edit event. See the README.
- The rule text is duplicated between this hook and `extension.mjs` on purpose (different platforms, no shared code). **Change them together.**
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
