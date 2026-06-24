# orfi-kit-persist-state

> Write a session handoff file so you can clear context and resume work later.

## What it does

Captures your current working state into a session-state file (`CLAUDE-SESSION-STATE.md`) so that you can safely `/clear` the conversation and pick the work back up in a fresh session without losing your place. It also reinforces the kit's guardrails while writing: do not panic, do not introduce code hacks that break the codebase or existing unit/integration tests, never lie, and stay transparent.

## When it fires / how to invoke

Run the slash command:

```
/orfi-kit-persist-state
```

## Prerequisites

- The **helper-files root** must be configured for the repo (run `/orfi-kit-set-helper-files-root`; if it isn't set, this command configures it on the spot). The root is recorded in the untracked `.orfi-kits/helper-files-root` pointer.

## Behavior / rules

- Resolves the helper-files root from `.orfi-kits/helper-files-root` (configuring it first if missing — no fallback to any default).
- Writes your current state to `<helper-files-root>\orfi-kits\CLAUDE-SESSION-STATE.md`.
- The intent is to persist enough state that you can clear the session and resume cleanly.
- While persisting, it carries the kit's guardrails: never panic, never introduce code hacks that break the codebase or older unit/integration tests, never lie, and stay transparent.

## Notes

- Pairs with `/orfi-kit-load-state`, which reads the same `<helper-files-root>\orfi-kits\CLAUDE-SESSION-STATE.md` file in full at the start of a new session to restore the handoff.
- The root is set with `/orfi-kit-set-helper-files-root` and is shared with orfi-ae-kit (one pointer per repo).
- The honesty and "no code hacks" rules echo the `orfi-guardrails` skill that governs all interactions in this kit.
