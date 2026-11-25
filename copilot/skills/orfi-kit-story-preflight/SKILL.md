---
name: orfi-kit-story-preflight
description: Prepare one story before planning — capture its acceptance criteria, architecture constraints, current behavior, AC-to-test bindings and execution prerequisites, reusing existing plan/spec evidence. Read-only toward code, Git and trackers; writes one preflight note under the helper-files root.
---

STORY: $ARGUMENTS

# Story Preflight

A lightweight starting check for **one story** — a Jira issue or a local task. It produces planning inputs only: it never writes the implementation plan and never changes code. Run it before planning with whatever tool you prefer (Superpowers, GSD, a custom agent, plain prompting). `/orfi-kit-story-dod` later verifies the finished story against the note this command writes.

## 0. Resolve the story and its storage

1. **Helper-files root.** Read `.orfi-kits/helper-files-root` in the current repo. If it is missing, STOP and run `/orfi-kit-set-helper-files-root` — ask the user for the absolute path (never search for, infer, or guess a location; no default), then continue. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.
2. **Story key.** Use the argument. If none, derive it from the current branch name only when it contains exactly one ticket ID (e.g. `feature/PANV-1234-short-name` → `PANV-1234`). Otherwise ask. A story with no tracker gets a short lowercase slug from the user. The key must be a safe folder name (letters, digits, `-`, `_`).
3. **Storage.** `<story-dir>` = `<kit-root>\stories\<STORY-KEY>`; the note is `<story-dir>\preflight.md`. Create the folder if missing. This is the only place this command writes.

## Boundaries

- **Read-only** toward source, Git, infrastructure and issue trackers. No branch/worktree creation, source edits, dependency installation, environment bootstrap, credential inventory, tests, builds, DoD runs or tracker transitions. The authorized executor owns those.
- **Discover, don't impose.** Find project instructions, requirement sources, decision records, environment guidance and commands through the repo's instructions, `<kit-root>\ONBOARDING.md`, supplied links or bounded file discovery. No required folder layout, language, tracker field or tool.
- **No duplicate ceremony.** No second plan, copied evidence packets, global "passed" flag, forced mutation tests or repeated setup. Unknown facts stay unknown. Predict test failures; never label them observed RED.
- **Firewall.** Never copy helper-files paths or this note's content into Jira tickets, PR text or code comments.

## 1. Reuse what exists

1. Read an existing `<story-dir>\preflight.md` first, plus any planning artifact that already covers this story (a spec, a Superpowers design/plan, a GSD phase plan). Any check below that such an artifact satisfies is cited by path/section and requirement revision — not redone.
2. Compare the story's current requirements, constraints and relevant code/config with the recorded sources. Refresh **only** missing or changed checks. Elapsed time or unrelated commits alone do not invalidate anything. A changed acceptance clause updates its bindings; changed source/test/config revisits only the affected discovery and commands.

## 2. Checks — in this order

1. **Requirements and readiness.** Read the authoritative story (Jira via the Atlassian MCP when the story is a ticket; otherwise the user's agreed brief) and preserve every acceptance clause **verbatim** before looking at implementation. Record the source revision (issue `updated` timestamp, or a dated local reference) and dependency links. Conflicting sources are resolved with the user, never silently merged. Check only the project's actual readiness policies; report facts, do not repair tracker metadata.
2. **Architecture and contracts.** Identify ownership boundaries, invariants, applicable decision records, APIs/events, consumers and blast radius. Cite documents or source. If no event/API impact is found, say so. A genuinely uncovered architectural decision is recorded as an **open item** (`adr-needed`) — do not write the ADR here.
3. **Current behavior and tests.** Only after requirements are captured, inspect the relevant implementation and tests. Cite paths and lines. Classify each clause: missing, partial, exists-unproven, already-proven or unknown. Existing code is not proof by itself.
4. **Acceptance design.** For each clause state setup, action/input, the observable semantic assertion, intended test location, required identity/data, and why the test would fail if the behavior were absent (predicted RED). Grade each binding DIRECT, PARTIAL, INDIRECT or UNBOUND; anything short of DIRECT is an open item. User-facing behavior needs browser evidence where project policy requires it; page-loaded / element-exists / no-error assertions do not prove behavior.
5. **Execution prerequisites.** Reference the known restore/build/test/run commands with working directory, required role/tenant and affected deployment. Resolve commands as `/orfi-kit-story-dod` does (`verification:` block in `<kit-root>\ONBOARDING.md` → the repo's `ONBOARDING.md` / `docs/ONBOARDING.md` / `CONTRIBUTING.md` → obvious repo convention → leave unknown). Never invent a command and perform no setup. Missing prerequisites are recorded as `execution-blocker` open items.
6. **Planning handoff.** Summarize for the planner: AC mapping, likely/confirmed/unknown change locations, test-first order, risks, commands. Preserve any approval boundary before implementation.

## 3. Persist one compact note

Write (or refresh in place — never append round-by-round narration) `<story-dir>\preflight.md`:

```markdown
# Preflight — <STORY-KEY>

**Updated:** <date>  **HEAD:** <short-sha>  **Branch:** <branch>  **Base:** <base-branch>
**Requirements source:** <issue key + updated timestamp | local brief reference>
**Verdict:** ready for planning | blocked for planning — <specific gap>

## Requirements
| AC | Clause (verbatim) |
|----|-------------------|

## Constraints & dependencies
## Current behavior
## AC → test bindings
| AC / clause | Setup | Action | Semantic assertion | Test location | Predicted RED | Binding |
|-------------|-------|--------|--------------------|---------------|---------------|---------|

## Commands & environment
## Reused evidence
## Open items
- [ ] OI-1 — <description> (kind: planning-blocker | execution-blocker | adr-needed | binding-gap | follow-up)

## Next action
```

When an existing spec/plan already holds a section, write only its reference and the remaining gaps.

**Open items are a contract with `/orfi-kit-story-dod`.** Its check 4 requires every item to end up resolved (`[x]` plus evidence) or explicitly accepted by the user (`accepted: <date>, <reason>`). Never delete an item to make it disappear; an item that turns out to be wrong is closed with the reason.

## 4. Verdict and report

- **Ready for planning** — requirements are clear, necessary constraints are identified, and every clause has a DIRECT planned binding.
- **Blocked for planning** — otherwise, naming the specific gap.

Execution-only blockers may coexist with *ready for planning* and must stay visible. Ready for planning is not implementation approval, not a DoD pass, and not permission to change Git, Jira or deployments.

Report in a few lines: story key, verdict, open-item count by kind, and the note path.
