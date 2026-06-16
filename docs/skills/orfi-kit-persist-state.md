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

- A worktree that sits alongside a `helper_files` directory (the command writes to `../helper_files/CLAUDE-SESSION-STATE.md`, relative to the current worktree). The expected layout is both directories living under a common parent (e.g. `C:\repos\`).

## Behavior / rules

- Writes your current state to `../helper_files/CLAUDE-SESSION-STATE.md`, resolved relative to the current worktree.
- The path assumes `helper_files` lives alongside your worktree under a shared parent directory.
- The intent is to persist enough state that you can clear the session and resume cleanly.
- While persisting, it carries the kit's guardrails: never panic, never introduce code hacks that break the codebase or older unit/integration tests, never lie, and stay transparent.

## Notes

- Pairs with `/orfi-kit-load-state`, which reads the same `../helper_files/CLAUDE-SESSION-STATE.md` file in full at the start of a new session to restore the handoff.
- The honesty and "no code hacks" rules echo the `orfi-guardrails` skill that governs all interactions in this kit.
