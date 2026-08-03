---
name: orfi-kit-cpp-code-review
user-invocable: true
allowed-tools: Bash(*), Read(*), Grep(*), Glob(*), Agent(*)
description: "Run a C++ code review that executes the enforcing tools (clang-format / clang-tidy / build / tests) and grounds style verdicts in the repo's own config rather than general C++ norms. Invoke with /orfi-kit-cpp-code-review [DIFF|FULL|RAW|SMART|BUGS|SECURITY|PERFORMANCE|<path>]."
---

# orfi-kit-cpp-code-review

Review C++ changes by **running the tools that enforce the rules**, then judging the things tools
can't see.

Invoked on request — `/orfi-kit-cpp-code-review [DIFF|FULL|RAW|SMART|BUGS|SECURITY|PERFORMANCE|<path>]`. This does not run on its
own; it's a review you ask for, typically before opening a PR.

Read-only with respect to your source: it runs tools and reports, and never rewrites the code under
review.

C++ only. C# has its own toolchain (`dotnet format`, `.editorconfig`, analyzers) and its own skill —
`orfi-kit-csharp-code-review`. The approach is shared; the tooling is not, so the two stay separate.

## Why this exists

The C# sibling exists because a misnamed member passed review: the reviewer reasoned from general
language norms — "constants are PascalCase, looks right" — instead of reading the rule the repo had
actually encoded. The rule was there, it covered the case, and one command would have caught it.

C++ has the same failure mode with sharper edges, because the reference points are weaker. Most C++
repos ship **no** `.clang-format` and **no** `.clang-tidy`, so there's often no encoded rule to read
at all — which makes it very tempting to fall back on "what C++ usually looks like." That temptation
is the thing to resist: with no config, the honest move is to follow the prevailing pattern in the
file you're reviewing and say that's what you did.

**Run the enforcers when they exist. Ground style verdicts in the repo's config or its prevailing
pattern — never in what C++ generally looks like.**

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

git diff --name-only "$BASE"...HEAD -- '*.cpp' '*.h' '*.hpp' '*.cc' '*.cxx' '*.inl'
```

**Do not use `git merge-base HEAD @{u}`.** `@{u}` is this branch's own remote, so it resolves to the
last *pushed* commit and the diff would silently omit every commit already pushed — reviewing a
fraction of the story while appearing to review all of it. On worktree-created branches the upstream
may also point at the epic rather than the branch's own remote, making it wrong twice.

Ask the user which scope they want when the default doesn't work — empty diff, no resolvable base, or
a diff big enough that whole-project tooling is cheaper. `FULL` reviews the whole project; a path
scopes it manually; `RAW` and `SMART` set the ownership style (see below) and can be combined with a
scope. **`FULL` is the unlikely case** — reach for it when onboarding to unfamiliar code or doing a
deliberate sweep, not for ordinary pre-PR review. Either way, say what scope you settled on and which
base it resolved to.

**Exclude vendored code.** C++ projects routinely check in third-party sources — `glm/`, `third_party/`,
`external/`, `vendor/`, single-header libraries. Reviewing those is noise: they follow their upstream's
conventions, not yours. Filter them out and say which paths you skipped. Generated files
(`ui_*.h`, `moc_*.cpp`, `qrc_*.cpp`) are excluded for the same reason.

## Read the config first

Before any naming or formatting call, read what actually governs it. `CONFIG.md` (next to this file)
lists the sources and what each one decides — read it if you need the details.

The short version: `.clang-format` for formatting and include order, `.clang-tidy` for naming and
static analysis, `compile_commands.json` for whether `clang-tidy` can run at all, and
`CMakeLists.txt` / `*.pro` for the language standard and warning flags. Both clang config files
resolve nearest-file-wins up the directory tree, so read the one closest to each changed file.

**Expect them to be missing.** That's the common case in C++, and it changes what you're entitled to
assert — see the authority ladder below. It is not an error and does not stop the review.

## Find the source of truth

Correctness and completeness need something to compare the code against. "Every stated requirement
implemented" assumes the requirements were stated *somewhere* — without that, you end up inferring
intent from the diff and then judging the diff against your own inference. The code becomes its own
spec and everything looks complete.

So find the intent before judging against it. Work down this ladder and stop at the first rung that
gives you something usable. **Every rung is optional.** Any of them may be missing, stale, or
unreadable — none of that is an error and none of it stops the review. Take the best rung available,
say which one it was, and move on.

1. **`ONBOARDING.md`** — this kit's own project reference, created by `/orfi-kit-init` under the
   helper-files root (resolve the untracked `.orfi-kits/helper-files-root` pointer to locate it; if
   the pointer is unset, this rung simply isn't available). Read it first: it names the **ADR / spec
   location**, the **test & verification commands**, and the **security gate**.
2. **A project instruction file** — `CLAUDE.md`, `AGENTS.md`, or similar at the repo root. These often
   document the real build and test commands, the architecture, and the conventions, which makes them
   both a source of truth and the answer to "what command does this project actually use?"
3. **`CLAUDE-SESSION-STATE.md`** (or `COPILOT-SESSION-STATE.md`) — the handoff file
   `/orfi-kit-persist-state` writes, in the same root. A prior session often recorded what it was
   building and which plan or ticket it was working from.
4. **PRD or spec** — often under `design/` or `docs/`. Many repos have none; that's normal.
5. **ADRs** — read the governing record in full, not just its title.
6. **A plan** — plans come in several shapes, and you don't need to know any tool's layout to use one.
   Learn where it lives from the rungs above or by asking the user; then read its scope and done-when
   criteria. A plan file sitting in the repo is just an input to read — whatever wrote it. Never
   invoke another kit to obtain one, and never require a particular format.
7. **PR body, commit messages, or the linked ticket** — weaker, but they state intent.
8. **Tests as executable spec** — tests encode intended behavior even when no prose does.
9. **Public API contracts and their Doxygen comments.**

**If you can't find any of it, ask the user.** They usually know where intent lives even when the
repo doesn't advertise it — a ticket, a design doc, or just a sentence describing what the change is
meant to do. Ask before concluding it's absent; absence should be established, not assumed.

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

## Decide the ownership style — then check against it

C++ has two legitimate memory idioms, and reviewing code against the wrong one produces noise instead
of findings. Establish which one applies **before** the judgment lane, the same way you establish the
config and the source of truth.

This is a **per-project decision**, and it varies by team, company, domain, and era. Embedded and
game code often stays with raw pointers deliberately; a modern service codebase may mandate smart
pointers; a Qt application sits naturally in between because the framework's ownership model is built
on raw parent-child pointers. There is no correct global answer, so never carry a default from one
project into another — resolve it fresh, from the project in front of you:

1. **The repo's `.clang-tidy`** — if it enables `cppcoreguidelines-owning-memory` (or a comparable
   check), the repo has *encoded* a smart-pointer policy. That's a real rule and it wins over
   everything below, including an explicit argument.
2. **A written project or org convention** — an ADR, a coding-standards doc, `ONBOARDING.md`, or a
   project instruction file (`CLAUDE.md` / `AGENTS.md`) that states the memory policy. You already read
   these for the source of truth; reuse what they said. A stated convention outranks whatever the code
   currently happens to do, since code lags policy.
3. **An explicit argument** — `RAW` or `SMART` (see below).
4. **The prevailing pattern** — read the module you're reviewing. Does it use `std::unique_ptr` /
   `std::shared_ptr` for ownership, or raw pointers with manual `delete` and Qt parent-child
   ownership? Follow what's there. This is rung 3 of the authority ladder applied to memory. Prefer
   the pattern in the file being changed over a project-wide average — a large C++ codebase often
   contains both, module by module.
5. **Ask the user** — only when it's genuinely mixed or ambiguous, e.g. new smart-pointer code sitting
   beside raw-pointer code with no clear direction. One question: *"Is raw-pointer ownership fine
   here, or should this move to smart pointers?"* Take the answer for this review; don't assume it
   holds for the next project.

Then say which mode you settled on and why, in the report's Sources line.

### The two modes

**`RAW` — raw pointers are fine.** Manual `new`/`delete`, raw pointers, and Qt parent-child ownership
are a legitimate style, not defects. Do **not** flag them, and do **not** suggest smart pointers as a
stylistic upgrade. Mention a smart pointer only where it would fix a specific lifetime bug the code
actually has, and name that bug.

**`SMART` — prefer smart pointers.** Raw *ownership* becomes reportable as a **non-blocking nit**:
a raw pointer that owns its allocation, where `std::unique_ptr` or `std::shared_ptr` would express the
lifetime in the type. Cite `file:line` and say which smart pointer fits. Still non-blocking — it's a
style preference, not a correctness failure, and blocking would make this mode unusable on any
existing codebase. Raw *non-owning* pointers and references are never flagged in either mode: an
observer pointer owns nothing and has nothing to convert.

### What both modes always flag

The mode changes only whether the *technique* is reportable. Genuine lifetime defects are findings
under either mode, without exception — a "smart pointers only" setting must never become a way to
bury bugs under style noise, and a `RAW` setting must never become permission to leak:

- Leaks on early-return or exception paths
- Double frees and use-after-free
- Dangling references and pointers outliving their target
- Missing or non-virtual destructors on polymorphic bases
- Rule of three/five/zero violations
- Mismatched `new[]` / `delete`, or `malloc` / `delete`
- Ownership no reader can determine from the code

## Run the tools

Don't describe what a tool would report — run it and show what it said. Unlike C#, there's no single
command that covers formatting, style, and analysis, so this is several.

**Formatting** — only meaningful when `.clang-format` exists:

```bash
clang-format --dry-run -Werror <changed files>
```

Reports what differs without touching the files. Never run `clang-format -i` — a review reports, it
doesn't rewrite the code under review.

**Naming and static analysis** — needs `.clang-tidy` *and* a compilation database:

```bash
clang-tidy -p build <changed files>
```

If `compile_commands.json` doesn't exist, `clang-tidy` can't resolve includes and its output is
unreliable. Say so and fall back to reading the code; do **not** reconfigure or rebuild the project to
produce one — generating a build database is a build action, not a review action.

**Build** — use the project's own configuration. Read `CMakeLists.txt` / `*.pro` (and any project
instruction file) for the generator, build directory, and flags rather than assuming:

```bash
cmake --build build          # or: make, ninja, msbuild
```

Watch for `-Wall -Wextra -Werror` (or `/W4 /WX`): whether warnings fail the build decides whether a
warning is a finding or a nit.

**Tests** — run whatever the project uses:

```bash
ctest --output-on-failure    # or the project's own test command
```

Read the actual summary line rather than trusting the exit code, and report the real
passed/failed/skipped counts. If the project has no tests at all, say that plainly — it's a material
fact about the change's verifiability, not a defect in the diff.

Then two companions:

- **`/orfi-kit-doxygen-docs`** — invoke the skill to confirm every changed public, protected, or
  exposed declaration in a header carries a Doxygen block, following the file's existing `/**` or
  `///` style. Where the repo ships the checker, **run it over the branch's touched headers**, not
  over your uncommitted work:

      # $BASE is the fork point resolved under Scope. Headers only — the checker
      # skips .cpp/.cc deliberately, since the API surface lives in the header.
      mapfile -t HDRS < <(git diff --name-only "$BASE"...HEAD -- '*.h' '*.hpp' '*.hh' '*.hxx' \
        | grep -vE '(^|/)(third_party|external|vendor)/|(^|/)(ui_|moc_|qrc_)')
      pwsh scripts/check-doxygen-docs.ps1 -Files $HDRS   # or: bash scripts/check-doxygen-docs.sh --files "${HDRS[@]}"

  **Use `--files`, not `--changed`.** `--changed` means `git diff HEAD` plus staged — *uncommitted*
  work only. At review time the tree is usually clean, so it resolves to an empty list and **exits
  0** — a pass that inspected nothing. The headers under review are the ones the branch committed,
  which is what the diff above yields. Filter the same vendored and generated paths excluded under
  Scope, or the run reports on upstream code that isn't yours to document.

  The checker lives in the reviewed repo's `scripts/`, not in this kit, and needs `pwsh` or bash. In
  C++ expect it to be absent more often than in C# — when it is, verify by reading the changed
  headers and say that is what you did. If the list comes back empty, that means the branch changed
  no headers — not that the docs passed; a zero-file run is **unconfirmed**, never clean.
- **`/security-review`** — run it **scoped to this branch's diff**, not the whole tree. Invoke it
  with exactly this prompt:

      /security-review Review only the changes introduced by the current branch relative to its
      integration branch $BASE — specifically the diff at $MERGE_BASE..HEAD. Do not review code that
      already exists on $BASE. Limit the review to source and test files; ignore planning and
      documentation changes.

  Substitute the values you resolved under Scope: **`$MERGE_BASE` is the fork-point commit** — the
  `BASE` variable in that snippet holds exactly this SHA — and **`$BASE` is the integration branch it
  forked from**, the parent `epic/*` branch or the trunk. Unscoped, the security pass reports
  pre-existing findings from the whole tree against a change that never touched them, which buries the
  ones this branch actually introduced. In C++ this matters more than usual: vendored trees under
  `third_party/` and `vendor/` are full of real findings that are not yours to fix.

  Record the verdict. Not available this session? Note it as `skipped (unavailable)` and move on.
  Don't reimplement security analysis here — it's its own skill with its own shape, and two copies
  would drift.

If the repo has its own build, lint, or test command documented anywhere, prefer that — it's what CI
will actually enforce.

If a tool can't run — not installed, no config, no compilation database — say so plainly and treat the
result as unconfirmed rather than clean. Missing tooling is extremely common in C++; it narrows the
review rather than failing it.

## This is enforced, not requested

`CONTRACT.conf` (next to this file) restates the unconditional steps above in a form a hook can
check: the two companion skills, the scope diff, and the `--changed` / `@{u}` / `clang-format -i`
traps. The `orfi-kit-verify-skill-contract.sh` Stop hook reads the session transcript and **blocks a
report-shaped reply when any of them has no `tool_use` record.**

It deliberately requires *less* than the C# contract. Missing `clang-format`, `clang-tidy`, and
`compile_commands.json` are the norm here, and a gate that fires on correct behaviour gets bypassed
and then ignored. So the build and test commands stay prose-mandated — they vary too much per project
to pin to literal strings — while the two companions and the diff are enforced.

- **The record is the evidence, the report is only a claim.** The transcript is written by the
  harness; asserting a step ran does not create its record.
- **Attempt, not success.** The *call* satisfies the contract, not its exit code. In C++ especially,
  a tool that cannot run is a normal and reportable outcome — but `skipped (unavailable)` is honest
  after trying, not instead of trying.
- **There is no talking past it.** Rewriting the report without new records blocks again.

Substituting your own reasoning for a mandated companion skill is the specific failure being
prevented.

## Judge what tools can't

The more valuable half, and in C++ it carries more weight than usual, because the tool lane is often
partly unavailable. Tools won't find any of this:

- **Internal correctness** — needs no spec, so this always runs. Trace the logic: edge cases, null and
  error paths, boundaries and off-by-ones, integer overflow, signed/unsigned mixing, uninitialized
  members, iterator invalidation, dangling references, use-after-move, unreachable branches.
- **Memory and lifetime** — check against the ownership mode you settled on above. The defect list
  there applies in every mode; whether raw ownership itself is reportable depends on the mode.
- **Const correctness** — methods that don't mutate should be `const`; parameters that aren't modified
  should be `const&`. `mutable` used to work around a design problem rather than to express one.
- **Header hygiene** — is each changed header self-contained? Would it compile if included first? Are
  includes ordered per the hierarchy in `CONFIG.md`? Includes that should be forward declarations
  (they slow every consumer's build). Include guards present and matching the file.
- **Performance** — only where it plausibly matters; don't micro-optimise cold paths. Unnecessary copies
  where a `const&` or `std::move` would do, pass-by-value of containers and strings, allocation inside
  loops, repeated lookups that could be hoisted, `std::endl` where `'
'` suffices, missing `reserve`
  before a known-size fill, O(n²) walks over data that could be indexed, and needless work in
  frequently-called paths (paint, update, event handlers). Say *why* it matters — a copy in a hot render
  loop is a finding; the same copy in one-time setup is not. `clang-tidy`'s `performance-*` checks cover
  part of this in the tool lane; this lane is for what they can't see.
- **Intent correctness** — does it do the *right* thing, not just a consistent thing? This one needs a
  source of truth from the step above. Name the rung you're judging against. Without any rung, say so
  rather than substituting your own assumption about what the code was meant to do.
- **Completeness** — every stated requirement implemented? Watch for half-done paths and leftover
  TODOs. Check against the plan's or story's done-when.
- **Test coverage** — for each behavior the diff adds or changes, is there a test that would fail if it
  broke? A green suite proves the *existing* tests pass, not that the new code is tested. Name the
  changed paths with no covering test. Check that new tests assert real behavior rather than restating
  the implementation, and that the edge cases traced above have tests, not just the happy path. Report
  uncovered paths by name; don't claim a coverage percentage unless a coverage tool produced one.
  Reviewing coverage is in scope; writing the missing tests is a separate job.
- **Design / ADR conformance** — if the step above turned up ADRs, check the code matches the decided
  architecture and call out divergence. If deployed reality overrides an ADR's literal text, that's
  fine — but note the contradiction rather than passing over it.
- **PRD / plan conformance** — if a PRD, spec, or plan was found, does the change satisfy it without
  drifting into doing more or less than asked?

Cite `file:line` or tool output for findings. "Looks correct" without tracing isn't a finding.

**Large diffs — fan out.** When the diff is too big to hold in one pass, dispatch subagents in
parallel: one per changed file, or one per dimension (correctness, memory/lifetime, headers,
completeness). Give each agent the config you read in the step above so they judge against the repo's
rules rather than their own instincts. Merge overlapping findings, keep the citation from whichever
pass traced it most precisely, and rank the consolidated set once — a pile of unranked per-file
reports isn't a review.

## Where a style finding gets its authority

If a convention isn't encoded anywhere, there's nothing to enforce — and inventing a rule from general
C++ habit is the mistake this skill exists to avoid. This matters more in C++ than in C#, because rung
1 is usually empty. Say which rung a style finding rests on:

1. **Repo config** — `.clang-format`, `.clang-tidy`, compiler flags. Cite the key or the check name.
   This is the one that makes something a real violation.
2. **Tool default in effect** — cite the check name (e.g. `readability-identifier-naming`).
3. **Prevailing pattern** — if the surrounding file and its siblings consistently use `m_` for members
   and `SCREAMING_SNAKE` for constants, that's the de facto style; cite examples with `file:line` and
   call it an unenforced convention. Worth mentioning, not worth blocking. Prefer the pattern in the
   **file being changed** over a project-wide guess: C++ projects often mix styles across modules, and
   consistency with immediate neighbours beats consistency with a distant average.
4. **Nothing** — leave it alone.

No `.clang-format` or `.clang-tidy` at all? Worth mentioning as a recommendation, since neither CI nor
a local build can enforce style without them — but it's a gap in the repo, not a problem with the
change. Everything in the judgment section is unaffected. `CONFIG.md` has a baseline you can offer as
a starting point; it's a seed to adopt, not a rule to enforce against a repo that already has its own.

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

- **Scope** — what was reviewed, the base it diffed against, the focus if you narrowed it, and which
  paths you excluded as vendored or generated.
- **Sources** — the config you read (or that none existed), which source-of-truth rung you judged
  intent against, and the ownership mode you resolved plus where it came from. A reader should never
  have to guess what the review was measured against.
- **Tools** — each command, its verdict, the output. Anything that couldn't run, and why.
- **Findings** — most important first, with `file:line`. For style findings, which authority rung and
  which config key or check name.
- **Verdict** — what blocks, what's a nit. If a tool couldn't run, the verdict is unconfirmed rather
  than clean.

Never report a clean review while a required lane is unrun. "I couldn't confirm" is always better than
a false pass.
