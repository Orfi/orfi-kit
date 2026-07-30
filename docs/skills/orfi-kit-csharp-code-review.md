# orfi-kit-csharp-code-review

> C# review that runs the enforcing tools (`dotnet format` / `build` / `test`) and grounds style verdicts in the repo's own config instead of general C# norms.

## What it does

Reviews C# changes in two lanes. The **tool lane** actually runs the enforcers — `dotnet format --verify-no-changes --diagnostics`, `dotnet build`, `dotnet test` — and pastes their output rather than describing what they'd probably say. The **judgment lane** covers what no tool can see: correctness, completeness, ADR and PRD conformance.

It exists because of a specific failure. A private `const` in PascalCase passed review and wasn't caught until the format gate, because the review reasoned from general C# knowledge ("constants are PascalCase, looks right") instead of reading the repo's `.editorconfig` — which declared `applicable_kinds = field` with a `_` prefix requirement. A `const` *is* a field, the rule covered it, and with `TreatWarningsAsErrors` set it was breaking the build the whole time. One command would have caught it.

Distinct from [`orfi-kit-code-review`](orfi-kit-code-review.md), which is language-agnostic, read-only, and reviews the whole codebase by reading it. This one is C#-specific, executes tooling, and defaults to the diff. C++ is deliberately out of scope — clang-format / clang-tidy / Doxygen is a different toolchain and belongs in its own skill.

## When it fires / how to invoke

User-invoked; it never runs on its own. Typically before opening a PR.

```
/orfi-kit-csharp-code-review
```

Optional scope argument: `DIFF` (default), `FULL` (whole solution), or an explicit path/project.

## Prerequisites

- A C# project and the .NET SDK (`dotnet format`, `build`, `test`).
- An `origin`/upstream branch to diff against for the default `DIFF` scope.
- Optional: `orfi-kit-xml-docs` for the doc-comment check. On Claude Code, `/security-review` for the security item.

## Behavior / rules

- **Scope** — defaults to the diff against the parent branch, resolved via `git merge-base`. Asks which scope you want when the default is unusable: empty diff, no resolvable base, or a diff large enough that whole-solution tooling is cheaper. Always states the scope it settled on.
- **Config first** — reads `.editorconfig`, `Directory.Build.props`, `.globalconfig`, `stylecop.json`, and per-project `.csproj` overrides *before* making any naming or formatting call. `.editorconfig` resolves nearest-file-wins up the tree to `root = true`, so it reads the one nearest each changed file. Naming rules are read as a full triplet (`dotnet_naming_rule` + `_symbols` + `_style`).
- **Read-only on source** — uses `--verify-no-changes` and never runs bare `dotnet format`. A review reports; it doesn't rewrite the code under review.
- **Real test numbers** — reads the test summary line rather than trusting the exit code, and reports actual passed/failed/skipped counts.
- **Unconfirmed ≠ clean** — if a tool can't run, it says so and treats the result as unconfirmed rather than passing.
- **Authority ladder for style findings** — every style finding names what it rests on: (1) repo config, citing the key — the only rung that yields a real violation; (2) analyzer/SDK default in effect, citing the diagnostic ID; (3) prevailing pattern in the codebase, cited with `file:line` and reported as an unenforced convention, non-blocking; (4) nothing — stays silent. It never fills rung 4 with textbook norms, which is the mistake it exists to prevent.
- **Missing `.editorconfig`** — mentioned as a recommendation (CI can't enforce style without one), not a defect in the change under review. `dotnet format`'s whitespace pass still works from built-in defaults, and the judgment lane is unaffected.
- **Large diffs fan out** — when a diff is too big for one pass, it splits the work by file or by dimension (correctness, completeness, ADR/PRD conformance), passes the config it read into each pass so judgments stay grounded in the repo's rules, then consolidates: overlapping findings merged, most precise citation kept, and the combined set ranked once. On Claude Code this dispatches parallel subagents; on Copilot it's a deliberate sequential split.
- **Security is delegated, not reimplemented** — security analysis needs adversarial threat-modeling and its own severity rubric, so the skill records a verdict from a dedicated security review rather than improvising one inline. Keeping one copy of that logic avoids drift between two.

## Per-runtime differences

| | Claude Code | Copilot CLI |
| --- | --- | --- |
| Doc-comment check | invokes `/orfi-kit-xml-docs` | uses the `orfi-kit-xml-docs` skill |
| Security item | invokes `/security-review`; records `skipped (unavailable)` if absent | no bundled security-review skill — records `not run` and suggests a dedicated review before merge |
| Large diffs | dispatches parallel subagents (one per file or dimension), then consolidates | splits the pass deliberately by file or dimension, then consolidates |

## `CONFIG.md`

The skill ships a `CONFIG.md` alongside `SKILL.md`, installed with it. It lists where rules come from and what each source decides, plus a baseline `.editorconfig` and `Directory.Build.props`.

The baseline is a **seed to adopt, never a rule to enforce**. Where a repo has its own config, that config is the contract and the baseline is only a comparison point — the skill may report gaps against it non-blockingly, but never flags a violation of it. This matters: a baseline used as authority would be textbook-norms with extra steps, which is the original failure mode wearing a different hat.

Notable in the baseline: `EnforceCodeStyleInBuild` is load-bearing — without it, IDE00xx style rules stay silent at build time no matter what `.editorconfig` says. `TargetFramework` is deliberately absent, since it isn't a style rule.

## Example

```
$ /orfi-kit-csharp-code-review

Scope: DIFF vs origin/master (base a1b2c3d) — 4 changed .cs files
Config: .editorconfig (root), Directory.Build.props (TreatWarningsAsErrors, EnforceCodeStyleInBuild)

dotnet format --verify-no-changes --diagnostics   FAILED
  src/Orders/OrderService.cs(23,27): IDE1006: Naming rule violation

dotnet build    FAILED (1 error, style enforced in build)
dotnet test     42 passed, 0 failed, 1 skipped
xml-docs        ok
security        /security-review — no findings

BLOCKING
  1. src/Orders/OrderService.cs:23 — private const MaxRetries is PascalCase.
     Authority: repo config — dotnet_naming_symbols.private_fields.applicable_kinds = field
     (const is a field); required_prefix = _. Expected _maxRetries.

NITS
  2. src/Orders/OrderService.cs:41 — field ordering differs from the prevailing
     pattern (unenforced convention; 12 of 14 peers put readonly fields first).

Verdict: 1 blocking finding.
```

## Notes

- Pairs with `orfi-kit-xml-docs` (doc comments) and the generic `orfi-kit-code-review` (language-agnostic, whole-codebase).
- Self-contained: depends only on the .NET SDK and, optionally, other orfi-kit skills. No dependency on any other kit.
