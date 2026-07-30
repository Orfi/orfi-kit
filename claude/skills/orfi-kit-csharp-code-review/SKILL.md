---
name: orfi-kit-csharp-code-review
user-invocable: true
allowed-tools: Bash(*), Read(*), Grep(*), Glob(*)
description: "Run a C# code review that executes the enforcing tools (dotnet format / build / test) and grounds style verdicts in the repo's own config rather than general C# norms. Invoke with /orfi-kit-csharp-code-review [DIFF|FULL|<path>]."
---

# orfi-kit-csharp-code-review

Review C# changes by **running the tools that enforce the rules**, then judging the things tools
can't see.

Invoked on request — `/orfi-kit-csharp-code-review [DIFF|FULL|<path>]`. This does not run on its own;
it's a review you ask for, typically before opening a PR.

C# only. C++ has its own toolchain (clang-format / clang-tidy / Doxygen) and belongs in a separate
skill — the approach generalizes, the tooling doesn't.

## Why this exists

A private `const` in PascalCase once passed review and wasn't caught until the format gate. The
review reasoned from general C# knowledge — "constants are PascalCase, looks right" — instead of
reading the repo's `.editorconfig`, which said:

    dotnet_naming_symbols.private_fields.applicable_kinds = field
    dotnet_naming_symbols.private_fields.applicable_accessibilities = private
    dotnet_naming_style.camel_case_with_underscore.required_prefix = _

A `const` **is** a field. The rule covered it, and with `TreatWarningsAsErrors` set it was breaking
the build the whole time. One command would have said so.

So: **run the enforcers, and ground style verdicts in the repo's config — not in what C# usually
looks like.**

## Scope

Default to the **diff** — what changed against the parent branch:

```bash
BASE=$(git merge-base HEAD @{u} 2>/dev/null || git merge-base HEAD origin/master)
git diff --name-only "$BASE"...HEAD -- '*.cs'
```

Ask the user which scope they want when the default doesn't work — empty diff, no resolvable base,
or a diff big enough that running tools per-project is slower than doing the whole solution. Pass
`FULL` to review the whole solution, or a path to scope it manually. Either way, say what scope you
settled on.

## Read the config first

Before any naming or formatting call, read what actually governs it. `CONFIG.md` (next to this file)
lists the sources and what each one decides — read it if you need the details.

The short version: `.editorconfig` for naming/format/usings, `Directory.Build.props` for
`TreatWarningsAsErrors` and `EnforceCodeStyleInBuild`, plus `.globalconfig`, `stylecop.json`, and
per-project `.csproj` overrides. `.editorconfig` cascades nearest-file-wins up to `root = true`, so
read the one nearest the changed file.

## Run the tools

Don't describe what a tool would report — run it and show what it said.

```bash
dotnet format <sln|csproj> --verify-no-changes --diagnostics
dotnet build            # honours the repo's TreatWarningsAsErrors
dotnet test             # changed projects, or all at FULL scope
```

`dotnet format` covers whitespace, IDE00xx style, and analyzers in one pass; `--diagnostics` names
each hit. Use `--verify-no-changes` — a review reports, it doesn't rewrite the code under review.

For tests, read the summary line rather than trusting the exit code, and report the real
passed/failed/skipped counts.

Then two companions:

- **`/orfi-kit-xml-docs`** — every changed `public` / `protected` / `static` member has a `///` block.
- **`/security-review`** — run it and record the verdict. Not available this session? Note it as
  `skipped (unavailable)` and move on. Don't reimplement security analysis here — it's its own skill
  with its own shape, and two copies would drift.

If the repo has its own lint command (a `make` target, script, or CI step), prefer that — it's what
CI will actually enforce.

If a tool can't run, say so plainly and treat the result as unconfirmed rather than clean.

## Judge what tools can't

The more valuable half. Tools won't find any of this:

- **Correctness** — does it do what it claims? Trace the logic: edge cases, null and error paths,
  boundaries, concurrency, cancellation, disposal.
- **Completeness** — every stated requirement implemented? Watch for half-done paths, leftover
  TODOs, and new behavior with no tests. Check against the story or plan's done-when.
- **Design / ADR conformance** — where ADRs exist, read the governing one properly and check the code
  matches the decided architecture. Call out divergence. If deployed reality or golden files override
  an ADR's literal text, that's fine — but note the contradiction rather than passing over it.
- **PRD conformance** — does the change satisfy what it claims, without drifting into doing more or
  less than asked?

Cite `file:line` or tool output for findings. "Looks correct" without tracing isn't a finding.

## Where a style finding gets its authority

If a convention isn't encoded anywhere, there's nothing to enforce — and inventing a rule from
general C# habit is the mistake this skill exists to avoid. Say which of these a style finding rests
on:

1. **Repo config** — cite the key. This is the one that makes something a real violation.
2. **Analyzer or SDK default in effect** — cite the diagnostic ID.
3. **Prevailing pattern** — if most existing fields are `_camelCase`, that's the de facto style; cite
   examples and call it an unenforced convention. Worth mentioning, not worth blocking.
4. **Nothing** — leave it alone.

No `.editorconfig` at all? Worth mentioning as a recommendation, since CI can't enforce style
without one — but it's a gap in the repo, not a problem with the change. `dotnet format`'s whitespace
pass still works from built-in defaults, and everything in the judgment section is unaffected.
`CONFIG.md` has a baseline you can offer as a starting point; it's a seed to adopt, not a rule to
enforce against a repo that already has its own.

## Report

- **Scope** — what was reviewed, and the base it diffed against.
- **Tools** — each command, its verdict, the output. Anything that couldn't run, and why.
- **Findings** — most important first, with `file:line`. For style findings, which authority rung
  and which config key.
- **Verdict** — what blocks, what's a nit. If a tool couldn't run, the verdict is unconfirmed rather
  than clean.
