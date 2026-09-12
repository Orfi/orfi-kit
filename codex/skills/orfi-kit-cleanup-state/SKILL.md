---
name: orfi-kit-cleanup-state
description: Strip internal scaffolding (.orfi-kits, .planning, .trackbed, docs/superpowers) from the branch before the final epic PR merge — backs up to helper_files/stripped first, then git rm. Destructive; prompts for confirmation.
---

You are finalizing the current branch for its **epic PR merge** by removing internal working scaffolding so it never lands in the merged history. This is **destructive** — it deletes tracked folders from the working tree and stages their removal. Run it only when the epic's work is done.

Folders stripped (only those that exist):

- `.orfi-kits/` — the kit pointer + state config
- `.planning/` — GSD planning scaffold
- `.trackbed/` — Trackbed roadmap/state
- `docs/superpowers/` — Superpowers specs & plans

**Step 1 — resolve the backup location.** Read `.orfi-kits/helper-files-root` to get the helper-files root. If it is missing, ask the user for it. The backup goes to `<helper-files-root>\stripped\` (flat).

**Step 2 — DANGER confirmation. Do NOT proceed without it.** Print this banner and the exact list of folders that exist and will be removed, then ask the user to type `yes` to proceed. If they do not explicitly confirm, stop and change nothing.

```
☠️  DANGER — DESTRUCTIVE CLEANUP  ☠️
This will DELETE the following tracked folders from this branch's working tree
and stage their removal for the final PR:
  <list the folders that actually exist here>
A backup copy is written to <helper-files-root>\stripped\ first.
This also removes your local .orfi-kits pointer — only run when the epic work is done.
Type 'yes' to proceed.
```

**Step 3 — back up first.** For each folder that exists, copy it (plain recursive copy, preserving structure) into `<helper-files-root>\stripped\<folder-name>\`. This backup lives outside git and survives the removal. (Flat layout: a second run overwrites a prior backup — that is expected.)

**Step 4 — remove from the branch.** For each folder that exists, run `git rm -r <folder>` so it is deleted from the working tree **and** the final committed tree (not merely gitignored).

**Step 5 — commit** the removal with a clear message (e.g. `chore: REMOVED: internal scaffolding before epic PR merge`).

**Step 6 — confirm** in one line: which folders were backed up + removed, the backup path, and the commit hash.
