# orfi-kit-set-helper-files-root

> Configure (create or change) the per-repo helper-files root that the session-state files live under.

## What it does

Records the **helper-files root** — the directory whose `orfi-kits/` subfolder holds the session-state handoff file and `ONBOARDING.md` — in a small pointer file (`.orfi-kits/helper-files-root`) inside the current repo. The state commands (`/orfi-kit-load-state`, `/orfi-kit-persist-state`) resolve their files relative to this root, so it must be configured before they can run.

The root is per-repo by design: each repo carries its own pointer, so different repos keep separate state and never overwrite each other. The same pointer is shared with orfi-ae-kit (if installed) — both kits read one root per repo. `.orfi-kits/` is **tracked** (it propagates across worktrees) and is stripped before the final epic PR by `/orfi-kit-cleanup-state`.

## How to invoke

```
/orfi-kit-set-helper-files-root <absolute-path>
```

If you omit the path, the command prompts you for it.

## Prerequisites

- An absolute path to the directory you want to use as the helper-files root (it may be outside the current repo).

## Behavior / rules

The command runs an idempotent config routine — it creates the configuration if absent and overwrites the path if it already exists:

1. Determine the path from the argument, or prompt for it. No fallback to any default.
2. Create `.orfi-kits/` in the current repo if missing.
3. Write `.orfi-kits/.gitignore` containing a single `*` so the whole folder stays untracked (the repo's root `.gitignore` is never touched).
4. Overwrite `.orfi-kits/helper-files-root` with the path (one line).
5. If `.orfi-kits/` was ever tracked, run `git rm --cached -r .orfi-kits/` so it becomes genuinely untracked.
6. Confirm the resolved root in one line.

## Notes

- Pairs with `/orfi-kit-load-state` and `/orfi-kit-persist-state`, which read the pointer this command writes.
- orfi-ae-kit ships an equivalent `/orfi-ae-kit-set-helper-files-root` that writes the same pointer — run either; they agree because there is one pointer per repo.
