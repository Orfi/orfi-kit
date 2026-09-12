---
name: orfi-kit-init
description: Bootstrap the per-repo helper-files root and create placeholder session-state + onboarding files (only if they do not already exist).
---

You are bootstrapping orfi-kit for the current repo. This is a **create-if-absent** operation — it never overwrites existing configuration or files. Only `orfi-kit-set-helper-files-root` may change an existing path.

**Step 1 — ensure the helper-files root is configured.**
Read `.orfi-kits/helper-files-root` in the current repo. If it is missing, run the config routine (STOP and ask the user for the absolute path to the helper-files root (never search for, infer, or guess a location; no default), create `.orfi-kits/`, write `.orfi-kits/helper-files-root` with the path). `.orfi-kits/` is tracked — do not gitignore it. Define `<kit-root>` = `<helper-files-root>\orfi-kits`.

**Step 2 — check whether already initialized.**
If `<kit-root>` exists and already contains `CODEX-SESSION-STATE.md` and `ONBOARDING.md`, then this repo is already initialized: tell the user so and **stop** — do not touch anything.

**Step 3 — create only the missing placeholder files** under `<kit-root>` (create the `<kit-root>` folder if needed). Never overwrite a file that already exists.

- `CODEX-SESSION-STATE.md` — placeholder with guiding comment headers for what the session should record. Use this skeleton:

```
# CODEX-SESSION-STATE.md — shared session handoff

<!-- Written in the Architect's first-person voice; both sessions read it. Fill in as work proceeds. -->

## Current phase / focus
<!-- what we are working on right now -->

## RELAY FILE STATE
<!-- which relay file is current/queued; the relay files have no timestamp, so this note is the freshness authority -->

## Decisions
<!-- decisions made this session -->

## Open / blocked
<!-- anything unresolved or needing a human decision -->
```

- `ONBOARDING.md` — placeholder with guiding comment headers for the project-specific detail that the agnostic orientation files defer to. Use this skeleton:

```
# ONBOARDING.md — project single source of truth

<!-- The orientation files are intentionally generic. Record all project-specific rules here. -->

## Project / stack
<!-- languages, frameworks, key infrastructure -->

## ADR / spec location
<!-- where architecture decision records live, if any (the Architect reads these in full) -->

## Test & verification commands
<!-- how to run unit/integration tests; any independent verification tools -->

## Security gate
<!-- which security review/tool applies and when -->

## Terminology & conventions
<!-- naming rules, terms that must NOT appear in team-facing artifacts, commit/PR conventions -->

## Phase map / merge order
<!-- if applicable -->
```

**Step 4 — confirm** in one line: the resolved `<kit-root>` and which files were created (vs. already present).
