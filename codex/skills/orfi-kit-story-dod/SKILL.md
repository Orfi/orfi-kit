---
name: orfi-kit-story-dod
description: Definition-of-Done gate for one story — verifies acceptance criteria, tests, build/lint, preflight open items, scope, commits, doc comments and security against sha-pinned evidence, then writes one compact gate stamp. Audits what was done; never implements.
---

STORY: $ARGUMENTS

# Story DoD Gate

Verify one story's Definition of Done with **evidence, not assertion**, and write a single compact stamp. You audit what the executor already did; you do not implement, fix, commit, push or transition tickets. Run it before opening or completing the story's PR, or at any time as a dry-run — the stamp is always current truth.

## 0. Resolve the story, storage and diff base

1. **Helper-files root.** Read `.orfi-kits/helper-files-root` in the current repo. If it is missing, STOP and run `$orfi-kit-set-helper-files-root` — ask the user for the absolute path (never search for, infer, or guess a location; no default), then continue. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.
2. **Story key.** Use the argument. If none, derive it from the current branch name only when it contains exactly one ticket ID; otherwise ask. A tracker-less story uses the slug it was given in preflight.
3. **Storage.** `<story-dir>` = `<kit-root>\stories\<STORY-KEY>`. Read `preflight.md` if present; write `dod.md`. Create the folder if missing.
4. **Diff base.** The story's work is `<merge-base>..HEAD`, where `<merge-base>` = `git merge-base HEAD <base>`. `<base>` is the `Base:` recorded in `preflight.md`, else the branch this one was cut from per the git conventions (`epic/*` for epic work, otherwise `origin/master`). If that is ambiguous, ask once. Record `<base>` and the merge-base sha in the note.

Re-read the files every run — never trust earlier conversation state.

## Preparation reuse

Use `preflight.md` (or the spec/plan it references) for the requirements register, constraints, open items and clause-to-test design. Do not run preflight again or demand a new packet. Planned bindings and predicted RED are **not** observed evidence and never satisfy a check on their own. No preflight note → requirements come from the tracker or the user's brief, and check 4 has no subject.

## Non-negotiables

- **Evidence, not assertion.** Every check yields a count, a filename, a grep result or a command summary. "Looks fine" is not evidence; unverifiable = red.
- **Verify the ledger; re-run only what is missing or stale.** Re-running is the fallback, not the default.
- **Binary.** Each check is pass, fail, skipped (with the reason) or waived by a human. No partial credit.
- **No silent passes.** A conditional check with nothing to verify is `skipped (n/a)`; a check whose subject exists but has no available verifier is **red**.
- **Read actual output.** An exit code of 0 is not evidence; capture real counts.

## Resolving the verification commands

Checks 2, 3, 7 and 9 need project commands. They come from an optional `verification:` block:

```yaml
verification:
  test: "dotnet test"
  build: "dotnet build"
  lint: "dotnet format --verify-no-changes"
  doc_check: "pwsh scripts/check-xml-docs.ps1 -Changed"
  project_dod_skill: $my-project-dod
```

Resolve each command in this order:

1. The `verification:` block in `<kit-root>\ONBOARDING.md` (section "Test & verification commands").
2. The same block in the repo's `ONBOARDING.md`, `docs/ONBOARDING.md` or `CONTRIBUTING.md`.
3. The repo's obvious convention — a lone `*.sln`, `package.json` scripts, a `Makefile` target.
4. **Ask the user once**, and offer to record the answer in `<kit-root>\ONBOARDING.md` so the next run is cheaper.

Never invent a command and never guess twice. No such subject in the repo (no test suite, nothing compiled) → `skipped (n/a)`. Subject exists but the command is unresolvable → **red**, naming the missing command. No `project_dod_skill` → check 9 does not exist.

## Evidence ledger and freshness

`dod.md` keeps an append-only `## Evidence ledger` for the life of the story. Anyone may add a row while working — you, the executor, the user — whenever a gate-relevant tool runs (a code review that ran format/build/test, a security review, a doc check):

`| <check #> | <result summary> | <sha> | <source: skill/command + artifact path> |`

Evidence is **fresh only when its sha equals `HEAD`**; any commit since invalidates it.

| Evidence state | Verdict |
|---|---|
| Ledger row, sha == `HEAD` | **pass** — cite it as `pass (prior run @ <sha>)` |
| Ledger row, sha != `HEAD` | **stale** — re-run; red if it cannot be re-run |
| No row, but a surviving artifact (`.trx`, JUnit XML, build log, review report) produced at `HEAD` | **pass** — read it and backfill the ledger row yourself |
| Only a conversational claim ("tests were green") | **not evidence** — ask for the summary line or output path (which becomes a row); else re-run, red, or a human waiver |

Provenance is irrelevant; recoverability is what counts.

## The checks

Run in order. Consult the ledger before running anything.

### Check 1 — Acceptance criteria

Verify every clause of every AC from the requirements register (`preflight.md`, or the tracker/brief). Never infer requirements from the implementation.

- **AC freshness.** For a Jira story, fetch the issue once and compare the current AC text with the register. An unrelated edit does not invalidate evidence for unchanged ACs; an added or changed clause needs its own evidence review — report it and hand it back to planning rather than silently rewriting the contract. A tracker-less story uses its approved brief.
- **AC evidence table** (in the `## DoD` section):

  | AC / clause | Test and assertion citation | Recorded result | Binding |
  |---|---|---|---|
  | AC-1 / outcome | test file + test name + assertion | passed; output artifact | DIRECT |

  Only `DIRECT` satisfies a behavioral clause (`PARTIAL`, `INDIRECT`, `UNBOUND` do not). Compound ACs get one row per clause, including roles, exclusions and negative conditions. Browser-visible behavior needs browser evidence; page-load, element-exists, click-only or no-error assertions prove nothing semantic. Negative assertions must show the action was actually processed. Non-executable deliverables cite the artifact and the direct inspection.
- **Pass:** every current clause is demonstrably met with direct semantic evidence. **Fail:** any clause unmet, changed without reviewed evidence, or only partially/indirectly bound.

### Check 2 — Tests

Ledger first (a code review that ran the suite at `HEAD` counts; so does a surviving result file). Otherwise run the resolved `test` command and record the summary line verbatim.

- **Pass:** suite ran at `HEAD`, all tests pass, no new failures versus the merge-base. **Fail:** any failure, error, or inability to run or recover a result.
- **Test effectiveness.** Inspect whether each important assertion would reject materially wrong behavior. Reuse recorded RED/GREEN evidence; do not manufacture another RED cycle. If doubt remains, run the smallest focused check that resolves it, restoring any temporarily changed file exactly. No mutation campaigns.

### Check 3 — Build / lint clean

Ledger first; otherwise run the resolved `build` and `lint` commands. **Pass:** no errors and no new warnings. **Fail:** any error or new warning introduced by the story. Record the output summary verbatim.

### Check 4 — Preflight open items settled

Read `## Open items` in `preflight.md`. Each item must be either resolved — `[x]` with evidence (a commit, a test, an ADR file, a confirmed environment) — or explicitly accepted by the user (`accepted: <date>, <reason>`). An item that was deleted rather than closed is a fail.

- **Pass:** every item is resolved or accepted. **Fail:** any item open, or resolved without evidence.
- No `preflight.md`, or no open items → `skipped (n/a)`.

### Check 5 — Scope and architecture

Inspect `git diff <merge-base>..HEAD`. Changes must serve the story's ACs and the preflight's change locations; list anything else with a concrete diff citation — do not silently accept adjacent improvements. Confirm the diff respects the constraints recorded in preflight (boundaries, API/event contracts, decision records). Reuse an existing code review that already covers them; otherwise inspect only the affected paths. Do not invent architecture rules.

- **Pass:** in scope and conformant. **Fail:** an out-of-scope change or an unresolved contract/decision violation.

### Check 6 — Commits clean

Inspect the commits in `<merge-base>..HEAD`.

- **Pass:** every message follows the repo's commit format (orfi-kit's git conventions when the repo has no other); no secrets, credentials or tokens in the diff (grep for obvious key/password/token patterns).
- **Fail:** any format violation or suspicious string.

### Check 7 — Doc comments *(conditional on the diff, not on tooling)*

Applies whenever the diff touches `.cs` or `.cpp`/`.h`/`.hpp` files; otherwise `skipped (n/a)`. Satisfy it by the first available route:

1. Fresh ledger evidence — a doc check or `$orfi-kit-csharp-code-review` / `$orfi-kit-cpp-code-review` run at `HEAD`.
2. `$orfi-kit-xml-docs` (C#) or `$orfi-kit-doxygen-docs` (C++) over the touched files.
3. The repo's checker — the resolved `doc_check`, or `scripts/check-xml-docs.ps1 -Changed` / `scripts/check-doxygen-docs.ps1` when present.

None available while the diff touches those files → **red** (`blockers: doc comments unverifiable`), never skipped. Also: grep the diff's code comments for narrative comments and for references to internal workflow artifacts (helper-files paths, preflight/DoD notes) — any hit fails; and test files must carry no doc-comment blocks.

- **Pass:** every touched `public`/`protected`/`static` member is documented, comments are clean, no doc blocks in tests.

### Check 8 — Security *(conditional)*

Fresh ledger evidence (a security review or a language code review's security pass at `HEAD`) passes, cited. Otherwise run an installed security-review skill over the story diff (Codex ships none by default). If no route is available, stamp `skipped (unavailable)` — visible, not blocking.

- **Pass:** no high/critical findings (record medium and below; they do not block). **Fail:** any unresolved high or critical finding.

### Check 9 — Project DoD pass-through *(only when declared)*

If `project_dod_skill` is declared, invoke it and record its verdict. **Pass:** it exits green. **Fail:** red or error. Not declared → this check does not exist.

## Waiver

Only a human may override a red gate. Record `gate: waived (<date>, reason: <short reason>, by user)` and the context in the `## DoD` section. Never grant a waiver yourself. The next run overwrites it with a fresh result.

## Stamp grammar

Exactly one line, overwritten each run, placed directly under the title of `dod.md`:

```
gate: green  (2026-07-18, 8/8 checks, tests 47/47)
gate: green  (2026-07-18, 7/8 checks, 1 skipped: security unavailable)
gate: red    (2026-07-18, blockers: tests 43/47 failed, open items OI-2 — see note)
gate: waived (2026-07-18, reason: release deadline, by user)
```

The check count is the number of applicable checks (8, or 9 with a project DoD skill) minus those skipped; skipped checks are named. Checks passed on prior evidence still count. Test counts come from real output only.

## dod.md structure

```markdown
# DoD — <STORY-KEY>
gate: <stamp>

## DoD
**Run:** <date>  **Result:** green | red | waived  **HEAD:** <sha>  **Base:** <base> @ <merge-base sha>
**Requirements:** pass | fail | waived  **Engineering:** pass | fail | waived

| # | Check | Result | sha | Evidence |
|---|-------|--------|-----|----------|
| 1 | acceptance criteria | pass | a1b2c3d | AC table below |
| 2 | tests | pass | a1b2c3d | 47/47 passed (summary line) |
| 3 | build/lint | pass (prior run) | a1b2c3d | csharp-code-review — 0 errors, 0 warnings |
| 4 | open items | pass | a1b2c3d | OI-1 resolved (commit), OI-2 accepted |
| 5 | scope/architecture | pass | a1b2c3d | 3 files, all within scope |
| 6 | commits | pass | a1b2c3d | 4 commits, format correct, no secrets |
| 7 | doc comments | pass (prior run) | a1b2c3d | xml-docs — 12/12 members documented |
| 8 | security | skipped (unavailable) | — | no security review available |

**AC evidence:** <table from check 1>
**Architecture:** <constraints and citations from check 5>
**Test effectiveness:** <RED/GREEN citation or assertion assessment>
**Blockers:** none | <list>

## Evidence ledger
| # | Result | sha | Source |
|---|--------|-----|--------|
```

Replace the `## DoD` section entirely each run; **only append** to `## Evidence ledger`. Keep the **Requirements** verdict (check 1) separate from **Engineering** (checks 2, 3, 5, 7, 8): passing tooling does not prove the ACs, and meeting the ACs does not excuse engineering failures. The overall gate needs every applicable check to pass or be waived.

## Report

Quote the stamp line. If red, list the blockers and what would turn each green. Do not fix anything, commit, push or touch Jira — the user decides the next step.
