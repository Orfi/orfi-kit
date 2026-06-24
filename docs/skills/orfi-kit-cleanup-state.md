# orfi-kit-cleanup-state

> Strip internal working scaffolding from the branch before the final epic PR merge — backs up first, then `git rm`. Destructive; prompts for confirmation.

## What it does

Finalizes a branch for its epic PR merge by removing internal working scaffolding so it never lands in merged history. It backs each folder up to `<helper-files-root>\stripped\` (outside git), then `git rm -r`s it so the folder is gone from the **final committed tree** — not merely gitignored. Folders handled (only those that exist):

- `.orfi-kits/` — the kit pointer + state config
- `.planning/` — GSD planning scaffold
- `.trackbed/` — Trackbed roadmap/state
- `docs/superpowers/` — Superpowers specs & plans

## How to invoke

```
/orfi-kit-cleanup-state
```

## Prerequisites

- Run on the branch being finalized (typically the epic branch), when the epic's work is done.
- The helper-files root must be resolvable (from `.orfi-kits/helper-files-root`, or you'll be prompted) — that's where the backup is written.

## Behavior / rules

1. Resolve the backup location: `<helper-files-root>\stripped\` (flat).
2. **DANGER confirmation** — prints a `☠️` banner listing exactly the folders that exist and will be removed, and requires the user to type `yes`. No confirmation → nothing changes.
3. Back up each existing folder to `<helper-files-root>\stripped\<folder-name>\` (plain copy, survives the removal).
4. `git rm -r` each existing folder (removes from working tree and final committed tree).
5. Commit the removal.
6. Confirm what was backed up + removed, the backup path, and the commit hash.

## Notes

- **Destructive.** It also removes your local `.orfi-kits` pointer — only run when the epic's work is done.
- Flat backup: a second run overwrites a prior `stripped/` backup. This is expected (one `helper_files` per repo; cleanup is a once-per-epic terminal step).
- This is the counterpart to keeping `.orfi-kits/`, `.planning/`, `.trackbed/`, and `docs/superpowers/` **tracked** during work so they propagate across worktrees — cleanup strips them at the end.
