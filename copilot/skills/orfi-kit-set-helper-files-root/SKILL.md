---
name: orfi-kit-set-helper-files-root
description: Configure (create or change) the per-repo helper-files root that the session-state files live under.
---

You are configuring the **helper-files root** for the current repo — the directory that holds the session-state handoff file (`COPILOT-SESSION-STATE.md`) and `ONBOARDING.md`. The orfi-kit state skills (`/orfi-kit-load-state`, `/orfi-kit-persist-state`) resolve those files relative to this root, so it must be set before they can run.

The root is recorded in a small pointer file inside the current repo: `.orfi-kits/helper-files-root`. It is per-repo by design, so different repos keep their own separate state without overwriting each other. The same pointer is shared with orfi-ae-kit (if installed) — both kits read one root per repo.

`.orfi-kits/` is **tracked** (committed) on working branches so the pointer propagates worktree → epic → child worktrees. It is stripped from the final tree before the epic's PR merge by `/orfi-kit-cleanup-state`. Do **not** gitignore it.

Run the **config routine** below. It is idempotent — it creates the configuration if absent and overwrites the path if it already exists.

1. **Determine the path.** Use the path from the arguments below. If no argument is given, STOP and ask the user for the absolute path to the helper-files root (never search for, infer, or guess a location; no default), then wait for their answer. Do not guess or fall back to any previous default.
2. **Create the config folder.** Create `.orfi-kits/` in the current repo root if it does not exist.
3. **Write the pointer.** Overwrite `.orfi-kits/helper-files-root` with exactly the path (one line, no quotes, no trailing blank lines).
4. **Confirm.** Report in one line: the resolved helper-files root and that the pointer was written to `.orfi-kits/helper-files-root`.

Arguments (the helper-files root path, optional): $ARGUMENTS
