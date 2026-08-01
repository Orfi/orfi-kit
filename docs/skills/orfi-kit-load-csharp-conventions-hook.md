# orfi-kit-load-csharp-conventions-hook

> Surfaces the repo's own C# naming and formatting rules **before** a `.cs` file is written, so the first draft is already compliant.

## What it does

This is a global `PreToolUse` hook on `Write` / `Edit` / `MultiEdit`. When the file being written is a `.cs` file, it reads the rules the target repo actually encodes and injects them into context *before* the edit happens:

- The **nearest `.editorconfig`**, walking up the tree and stopping at `root = true` (nearest-file-wins, which is how `.editorconfig` really resolves). Only the `[*]` and `[*.cs]` sections are emitted — never a whole file.
- `dotnet_naming_rule` / `dotnet_naming_symbols` / `dotnet_naming_style` regrouped into **complete triplets**. A rule on its own is meaningless: split across the output you cannot tell which symbols it selects or what style it applies, so the hook prints each rule together with its symbol and style keys.
- `TreatWarningsAsErrors`, `EnforceCodeStyleInBuild`, and `Nullable` from the nearest `Directory.Build.props`.

The problem it solves: conventions used to be consulted only at review time, so code got written blind to the repo's own config and fixed afterwards — or shipped and caught by CI. This moves the rules to write time.

## When it fires / how to invoke

Passive — it runs automatically. Matchers in `settings.json` match **tool names**, not file globs, so the hook is wired to `Write|Edit|MultiEdit` and does its own `*.cs` filtering from `.tool_input.file_path`. Non-`.cs` paths exit 0 silently. You never invoke it directly.

## Prerequisites

None. `jq` is used when present and `sed` is the fallback, so no external tool is required. Generated files (`*.g.cs`, `*.designer.cs`, `*.generated.cs`) and `Migrations/` are skipped.

## Behavior / rules

- **The repo under review always wins.** When the repo encodes rules, the hook reports only those and invents nothing.
- **If the repo encodes nothing, the kit's own baseline is enforced as the contract.** With no `.editorconfig` and no `Directory.Build.props`, the hook reads the baseline out of the code-review skill's `CONFIG.md` (from `~/.claude/skills/`, `~/.copilot/skills/`, or the OpenCode path) and states that deviation is a violation, including in pre-existing code you touch. The baseline is read from disk rather than duplicated in the hook, so it can never drift from the `CONFIG.md` that documents it.

  Precedence is unchanged: **the repo always wins.** This only fires when there is nothing to win against. And it is honest about its own limit — with no `.editorconfig` in the repo, `dotnet format` has nothing to read, so the baseline is enforced by reading it, not by a tool. The hook says so, and points out that adopting the baseline as the repo's own `.editorconfig` is what makes it enforceable by the build and CI.

- If the baseline is not installed either, then nothing is enforceable: the hook says so and defers to the prevailing pattern of the surrounding file. It never substitutes general C# habit for a rule nobody set.
- **Read-only.** The hook never writes config into your repo. Adopting the baseline is a deliberate act, not a side effect of editing a file.
- It always states that `applicable_kinds = field` **covers `const` and `static readonly`**. A `const` *is* a field, so a field rule such as `required_prefix = _` applies to it. Misreading this is a known cause of mass naming violations: a PascalCase private `const` has passed review and broken the build under `TreatWarningsAsErrors`.
- When `TreatWarningsAsErrors` is `true` it says so explicitly — a style or naming warning is a build break, not a nit.
- **Advisory: it never blocks a write.** Exit is always 0.
- Output is capped (`ORFI_CONVENTIONS_MAX_LINES`, default 120) so a large config cannot flood the context.

## Example

Editing a `.cs` file in a repo whose `.editorconfig` requires an `_` prefix on private fields:

```
[ORFI C# CONVENTIONS — the repo's own rules for MigrateApprovalCommand.cs]
These come from this repo's config and outrank general C# habit. Write the
first draft compliant; do not defer naming and formatting to review or CI.

--- /path/to/.editorconfig
indent_style = space
indent_size = 4
csharp_style_namespace_declarations = file_scoped:warning
...

  Naming rules as COMPLETE TRIPLETS (rule -> symbols -> style):
  * rule 'private_fields_should_be_camel_case' (severity: warning)
      symbols 'private_fields':
        dotnet_naming_symbols.private_fields.applicable_kinds = field
        dotnet_naming_symbols.private_fields.applicable_accessibilities = private
      style 'camel_case_with_underscore':
        dotnet_naming_style.camel_case_with_underscore.required_prefix = _
        dotnet_naming_style.camel_case_with_underscore.capitalization = camel_case

  READ applicable_kinds LITERALLY: 'field' COVERS const AND static readonly.

--- /path/to/Directory.Build.props
  TreatWarningsAsErrors = true
  EnforceCodeStyleInBuild = true
  Nullable = enable
  => Warnings FAIL the build.
```

## Notes

- Pairs with `orfi-kit-verify-csharp-format-hook`, which checks the file *after* it is written.
- The Copilot side loads the same rule text via the guardrails extension (`onSessionStart`), but has **no verifier** — that SDK exposes no per-edit event. See the README.
- The rule text is duplicated between this hook and `extension.mjs` on purpose (different platforms, no shared code). **Change them together.**
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
