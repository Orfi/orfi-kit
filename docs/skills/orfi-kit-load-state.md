# orfi-kit-load-state

> Restore your previous Claude Code session by reading the session handoff file before doing anything else.

## What it does

Reads the Claude Code session handoff file `CLAUDE-SESSION-STATE.md` in full so you pick up where a prior session left off. This is the "load" half of the session-continuity pair: one session writes its state, and at the start of the next you load it back in so context carries across sessions.

## How to invoke

Run the slash command:

```
/orfi-kit-load-state
```

## Prerequisites

- A `CLAUDE-SESSION-STATE.md` file must exist at `../helper_files/CLAUDE-SESSION-STATE.md` (a `helper_files` directory sitting alongside the current worktree). Typically this is written by a prior session.

## Behavior / rules

- Reads `../helper_files/CLAUDE-SESSION-STATE.md`, resolved relative to the current worktree (the worktree sits alongside `helper_files`).
- Reads the file **in full before doing anything else** — loading state is the first action of the session, ahead of any other work.

## Notes

- Pairs with `/orfi-kit-persist-state`, which writes the session state that this command reads back. Run persist-state at the end of a session and load-state at the start of the next.
