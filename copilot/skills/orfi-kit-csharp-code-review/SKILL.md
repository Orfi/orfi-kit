---
name: orfi-kit-csharp-code-review
description: "Run a C# code review that executes the enforcing tools (dotnet format / build / test) and grounds style verdicts in the repo's own config rather than general C# norms. Invoke with /orfi-kit-csharp-code-review [DIFF|FULL|BUGS|SECURITY|PERFORMANCE|<path>]."
---

# orfi-kit-csharp-code-review

Review C# changes by **running the tools that enforce the rules**, then judging the things tools
can't see.

Invoked on request — `/orfi-kit-csharp-code-review [DIFF|FULL|BUGS|SECURITY|PERFORMANCE|<path>]`. This does not run on its own;
it's a review you ask for, typically before opening a PR.

Read-only with respect to your source: it runs tools and reports, and never rewrites the code under
review — `--verify-no-changes` only, never bare `dotnet format`.

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

Default to the **diff** — the whole body of work on this branch, not just its unpushed commits. In
practice that's a story or a phase: everything that will land when this branch merges.

Resolve the base as the branch's **fork point from its parent**, in this order:

```bash
# 1. If this is an epic-derived working branch, the parent is its epic branch.
git fetch origin >/dev/null 2>&1
for e in $(git branch -r --list 'origin/epic/*' --format='%(refname:short)'); do
  git merge-base --is-ancestor "$e" HEAD 2>/dev/null && BASE=$(git merge-base "$e" HEAD)
done
# 2. Otherwise fall back to the trunk.
: "${BASE:=$(git merge-base HEAD origin/master 2>/dev/null || git merge-base HEAD origin/main)}"

git diff --name-only "$BASE"...HEAD -- '*.cs'
```

**Do not use `git merge-base HEAD @{u}`.** `@{u}` is this branch's own remote, so it resolves to the
last *pushed* commit and the diff would silently omit every commit already pushed — reviewing a
fraction of the story while appearing to review all of it. On worktree-created branches the upstream
may also point at the epic rather than the branch's own remote, making it wrong twice.

Ask the user which scope they want when the default doesn't work — empty diff, no resolvable base, or
a diff big enough that running tools per-project is slower than doing the whole solution. Pass `FULL`
to review the whole solution, or a path to scope it manually. **`FULL` is the unlikely case** — reach
for it when onboarding to unfamiliar code or doing a deliberate sweep, not for ordinary pre-PR review.
Either way, say what scope you settled on and which base it resolved to.

## Read the config first

Before any naming or formatting call, read what actually governs it. `CONFIG.md` (next to this file)
lists the sources and what each one decides — read it if you need the details.

The short version: `.editorconfig` for naming/format/usings, `Directory.Build.props` for
`TreatWarningsAsErrors` and `EnforceCodeStyleInBuild`, plus `.globalconfig`, `stylecop.json`, and
per-project `.csproj` overrides. `.editorconfig` cascades nearest-file-wins up to `root = true`, so
read the one nearest the changed file.

## Find the source of truth

Correctness and completeness need something to compare the code against. "Every stated requirement
implemented" assumes the requirements were stated *somewhere* — without that, you end up inferring
intent from the diff and then judging the diff against your own inference. The code becomes its own
spec and everything looks complete. That's the same circularity as asserting a naming rule from C#
habit instead of `.editorconfig`.

So find the intent before judging against it. Work down this ladder and stop at the first rung that
gives you something usable. **Every rung is optional.** Any of them may be missing, stale, or
unreadable — none of that is an error and none of it stops the review. Take the best rung available,
say which one it was, and move on.

1. **`ONBOARDING.md`** — this kit's own project reference, created by the `orfi-kit-init` skill under the
   helper-files root (resolve the untracked `.orfi-kits/helper-files-root` pointer to locate it; if
   the pointer is unset, this rung simply isn't available). Read it first: it names the **ADR / spec
   location**, the **test & verification commands**, and the **security gate**, so it usually points
   at the rungs below instead of making you guess at directory names.
2. **`COPILOT-SESSION-STATE.md`** — the handoff file
   the `orfi-kit-persist-state` skill writes, in the same root. A prior session often recorded what it was
   building and which plan or ticket it was working from.
3. **PRD or spec** — if one exists. Many repos have none; that's normal, not a defect.
4. **ADRs** — read the governing record in full, not just its title.
5. **A plan** — plans come in several shapes, and you don't need to know any tool's layout to use one.
   Learn where it lives from `ONBOARDING.md`, the session-state file, or by asking the user; then read
   its scope and done-when criteria. A plan file sitting in the repo is just an input to read —
   whatever wrote it. Never invoke another kit to obtain one, and never require a particular format.
6. **PR body, commit messages, or the linked ticket** — weaker, but they state intent.
7. **Tests as executable spec** — tests encode intended behavior even when no prose does.
8. **Public API contracts and their doc comments.**

**If you can't find any of it, ask the user.** They usually know where intent lives even when the
repo doesn't advertise it — a ticket, a wiki page, a design doc, or just a sentence describing what
the change is meant to do. Ask before concluding it's absent; absence should be established, not
assumed.

Stay resilient throughout. A rung that's missing, empty, stale, or contradicts another rung is
normal, not a failure: prefer the higher rung, note the contradiction, keep going. Never block, error
out, or refuse to review because a document wasn't there — and never treat a document's absence as a
defect in the code under review.

If it's genuinely unavailable, **do what you can with what you have** — review, don't refuse. Most of
this skill needs no spec at all: the whole tool lane, every internal-correctness check, and test
coverage all work fine without one. Say **"completeness unverifiable — no source of truth found"**,
name the strongest rung you did find (even if that was only the commit message), and carry on with
the rest. A missing spec narrows the review; it doesn't stop it. Just don't quietly upgrade a
narrowed review into a clean bill of health — and don't invent the intent you couldn't find.

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

If the repo already collects coverage — a `coverlet` package, a `--collect` flag in its test script,
or a coverage step in CI — run that and use the real numbers for the changed files. If it doesn't,
don't bolt a collector on: assess coverage by reading the tests against the diff instead (below).

Then two companions:

- **`orfi-kit-xml-docs`** — use the skill to confirm every changed `public` / `protected` / `static`
  member has a `///` block.
- **A security pass** — Copilot CLI has no bundled security-review skill, so note security as
  `not run (no security-review skill available)` rather than skipping it silently, and suggest a
  dedicated security review before merge. Don't improvise security analysis inline here — it needs
  adversarial threat-modeling and its own severity rubric, which is a different job from this review.

If the repo has its own lint command (a `make` target, script, or CI step), prefer that — it's what
CI will actually enforce.

If a tool can't run, say so plainly and treat the result as unconfirmed rather than clean.

## Judge what tools can't

The more valuable half. Tools won't find any of this:

- **Internal correctness** — needs no spec, so this always runs. Trace the logic: edge cases, null and
  error paths, boundaries and off-by-ones, concurrency, cancellation, disposal, swallowed exceptions,
  unreachable branches. A bug that's self-evident from the code is still a bug.
- **Performance** — only where it plausibly matters; don't micro-optimise cold paths. Allocation inside
  loops, LINQ chains that enumerate repeatedly or materialise needlessly, `async` methods missing
  `ConfigureAwait` in library code, sync-over-async (`.Result` / `.Wait()`), string concatenation in
  loops where a `StringBuilder` fits, boxing in hot paths, N+1 query patterns, and `IEnumerable`
  re-enumeration. Say *why* it matters — the same allocation in a request path and in startup are not
  the same finding.
- **Intent correctness** — does it do the *right* thing, not just a consistent thing? This one needs a
  source of truth from the step above. Name the rung you're judging against. Without any rung, say so
  rather than substituting your own assumption about what the code was meant to do.
- **Completeness** — every stated requirement implemented? Watch for half-done paths and leftover
  TODOs. Check against the story or plan's done-when.
- **Test coverage** — for each behavior the diff adds or changes, is there a test that would fail if
  it broke? A green suite proves the *existing* tests pass, not that the new code is tested — a diff
  can add three branches, leave every test passing, and be entirely uncovered. Name the changed paths
  with no covering test. Check that new tests assert real behavior rather than restating the
  implementation, and that the edge cases traced under Correctness have tests, not just the happy
  path. Report uncovered paths by name; don't claim a coverage percentage unless a coverage tool
  produced one. Reviewing coverage is in scope; writing the missing tests is a separate job.
- **Design / ADR conformance** — if the step above turned up ADRs, check the code matches the decided
  architecture and call out divergence. If deployed reality or golden files override an ADR's literal
  text, that's fine — but note the contradiction rather than passing over it.
- **PRD / plan conformance** — if a PRD, spec, or plan was found, does the change satisfy it without
  drifting into doing more or less than asked?

Cite `file:line` or tool output for findings. "Looks correct" without tracing isn't a finding.

**Large diffs — split the work.** When the diff is too big for one pass, break it up deliberately:
by file, or by dimension (correctness, completeness, ADR/PRD conformance). Carry the config you read
above into each pass so every judgment stays grounded in the repo's rules. Then consolidate — merge
overlapping findings, keep the most precise citation, and rank the combined set once. A pile of
unranked per-file reports isn't a review.

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

## Focus modes

By default every lane runs. Pass one or more focus keywords to narrow the judgment lane to a single
axis when that's all you want — useful for a quick pass or a second look at one dimension:

- `BUGS` — internal correctness only
- `SECURITY` — the security item only
- `PERFORMANCE` — the performance lane only

Combine with commas (`BUGS,PERFORMANCE`). Focus modes can be combined with a scope
(`DIFF BUGS`, `FULL PERFORMANCE`).

**The tool lane always runs**, whatever the focus — it's cheap, it's the part that catches what
reasoning misses, and a review that skipped it would be worthless. Focus narrows judgment, not
verification. Say which focus you used in the report, so a narrow pass is never mistaken for a full
review.

## Report

- **Scope** — what was reviewed, the base it diffed against, and the focus if you narrowed it.
- **Sources** — the config you read, and which source-of-truth rung you judged intent against (or
  that none was found). A reader should never have to guess what the review was measured against.
- **Tools** — each command, its verdict, the output. Anything that couldn't run, and why.
- **Findings** — most important first, with `file:line`. For style findings, which authority rung
  and which config key.
- **Verdict** — what blocks, what's a nit. If a tool couldn't run, the verdict is unconfirmed rather
  than clean.
