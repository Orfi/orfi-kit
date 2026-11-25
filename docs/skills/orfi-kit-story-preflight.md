# orfi-kit-story-preflight

> Prepare one story before planning — capture its acceptance criteria, constraints, current behavior, AC-to-test bindings and execution prerequisites, reusing existing plan/spec evidence.

## What it does

A lightweight starting check for a **single story** (a Jira issue or a local task). It reads the authoritative requirements and preserves every acceptance clause verbatim, then identifies architecture constraints and contracts, inspects the relevant current code and tests, designs a semantic test binding for each clause (with predicted RED), and records the commands and prerequisites needed to execute. The result is one compact note with a verdict — **ready for planning** or **blocked for planning** — and a list of open items.

It produces planning inputs only. The implementation plan is written afterwards by whatever tool you prefer (Superpowers, GSD, a custom agent, plain prompting); `orfi-kit-story-dod` later verifies the finished story against this note. It needs no roadmap, epic or planning framework. It was adapted from Trackbed's `trackbed-preflight`, cut down to the per-story part.

## How to invoke

```
/orfi-kit-story-preflight [STORY-KEY]      # Claude Code, OpenCode, Copilot CLI
$orfi-kit-story-preflight [STORY-KEY]      # Codex CLI
```

With no key, it uses the single ticket ID in the current branch name (e.g. `feature/PANV-1234-...`), otherwise it asks. A story with no tracker uses a short slug you supply.

## Prerequisites

- The helper-files root configured (`/orfi-kit-set-helper-files-root`; prompted on the spot if missing).
- The Atlassian MCP server for Jira stories. Local stories need no Jira access.

## Behavior / rules

1. **Storage.** Writes only `<helper-files-root>\orfi-kits\stories\<STORY-KEY>\preflight.md`, refreshed in place.
2. **Reuse first.** An existing preflight note, spec, Superpowers design/plan or GSD plan that already covers a check is cited by reference, not redone. Only missing or changed inputs are refreshed.
3. **Checks, in order:** requirements and readiness → architecture and contracts → current behavior and tests → acceptance design (DIRECT / PARTIAL / INDIRECT / UNBOUND bindings) → execution prerequisites → planning handoff.
4. **Open items.** Anything unresolved — planning blockers, execution blockers, a needed ADR, a binding gap — is listed as `OI-n`. `orfi-kit-story-dod` check 4 requires each item to be resolved with evidence or explicitly accepted by you; items are never deleted to make them disappear.
5. **Read-only** toward source, Git, infrastructure and Jira: no edits, installs, environment setup, tests, builds or ticket changes. Commands are referenced, never invented.
6. **Firewall.** Helper-files paths and note content never go into Jira, PR text or code comments.

## Notes

- Pairs with [`orfi-kit-story-dod`](orfi-kit-story-dod.md).
- Ready for planning is not implementation approval and not a DoD pass.
