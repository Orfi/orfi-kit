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

- The **helper-files root** must be configured for the repo (run `/orfi-kit-set-helper-files-root`; if it isn't set, this command configures it on the spot). The root is recorded in the untracked `.orfi-kits/helper-files-root` pointer.
- A `CLAUDE-SESSION-STATE.md` file must exist at `<helper-files-root>\orfi-kits\CLAUDE-SESSION-STATE.md`. Typically this is written by a prior session.

## Behavior / rules

- Resolves the helper-files root from `.orfi-kits/helper-files-root` (configuring it first if missing — no fallback to any default).
- Reads `<helper-files-root>\orfi-kits\CLAUDE-SESSION-STATE.md`.
- Reads the file **in full before doing anything else** — loading state is the first action of the session, ahead of any other work.

## Notes

- Pairs with `/orfi-kit-persist-state`, which writes the session state that this command reads back. Run persist-state at the end of a session and load-state at the start of the next.
- The root is set with `/orfi-kit-set-helper-files-root` and is shared with orfi-ae-kit (one pointer per repo).
