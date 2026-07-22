# orfi-kit-sync-branch

> Sync an epic-derived working branch (any prefix) through its full parent hierarchy (`origin/master` -> `epic/*` -> working branch) before you push.

## What it does

When you work in a two-level branch hierarchy (`master -> epic -> feature`), syncing your feature branch straight to master is not enough — the epic branch may have moved ahead, so your feature diverges from it and you hit conflicts when it eventually merges back into the epic. This command performs the sync in the correct order: it brings the parent epic up to date with `origin/master`, pushes the epic, then rebases your feature branch onto the freshly-updated epic. It also detects whether the epic has historically been kept in sync via merge or rebase and applies the matching strategy instead of guessing.

## When it fires / how to invoke

Run it manually from a session whose current worktree is on an epic-derived working branch (any prefix — `feature/`, `fix/`, `chore/`, …):

```
/orfi-kit-sync-branch
```

Run it before every `git push` on a feature branch that lives under an epic branch. It does not auto-invoke from the model — it is triggered explicitly by the slash command (or after you resolve a conflict and re-run it to finish).

## Prerequisites

- The current worktree must be on an epic-derived working branch (any prefix). The command aborts only if the branch is `master` or an `epic/*` branch.
- A remote named `origin` with `git fetch` available.
- Branch naming convention: an epic-derived working branch `{prefix}/{id}-{name}` (e.g. `feature/`, `fix/`, `chore/`) under `epic/{id}-{name}`.
- The parent epic must have a checked-out worktree at `C:/repos/wt-{epic-id}-{epic-slug}` (e.g. `epic/ORFI-60446-public-api` -> `C:/repos/wt-60446-public-api`). If the worktree is not listed by `git worktree list`, the command aborts and tells you to create it with `git worktree add`.
- Each feature branch has exactly one parent epic branch.

## Behavior / rules

The command runs eight steps in order, without asking for confirmation unless a conflict forces a decision:

1. **Verify branch** — confirms the current branch is an epic-derived working branch (any prefix); aborts only on `master` or `epic/*`. Records `FEATURE_BRANCH` and `FEATURE_WORKTREE`.
2. **Resolve parent epic** — reads `.claude/hooks/state/parent-epic` first; if missing/empty, fetches and scans `origin/epic/*` remote branches and uses `git merge-base` to pick the candidate whose tip is the closest ancestor of HEAD. If it still cannot decide, it asks you which epic is the parent.
3. **Locate epic worktree** — derives the expected path `C:/repos/wt-{epic-id}-{epic-slug}` and confirms it via `git worktree list`; aborts if absent.
4. **Fetch** — `git fetch origin --prune`.
5. **Detect strategy and sync epic with master** — inspects the epic history for merge commits and checks whether the epic HEAD has two parents:
   - Merge commits exist, or epic HEAD has 2 parents -> **MERGE**: `git merge origin/master` then a regular `git push origin <epic>` (no force; merges do not rewrite history).
   - Linear history, no merge commits -> **REBASE**: `git rebase origin/master` then `git push --force-with-lease origin <epic>`.
6. **Rebase feature on epic** — `git rebase <epic>` inside the feature worktree.
7. **Record state** — writes the resolved epic to `.claude/hooks/state/parent-epic` and a UTC timestamp to `.claude/hooks/state/last-sync-timestamp`.
8. **Report** — prints a completion summary and the exact `git push --force-with-lease origin <feature>` command to run next.

**Conflict handling:** at any merge or rebase step, if a conflict occurs the command STOPS and reports the conflicting files plus the resolution command (`git merge --continue` or `git rebase --continue`) to run in the affected worktree. After you resolve, run `/orfi-kit-sync-branch` again to complete the sync.

Note that the command does not push your feature branch for you — it leaves you ready to push and prints the command.

## Example

For a feature branch under `epic/ORFI-60446-public-api`:

- The epic worktree is expected at `C:/repos/wt-60446-public-api`.
- If you cannot determine the parent automatically, the command asks: "Which epic branch is the parent of {FEATURE_BRANCH}? (e.g. epic/ORFI-60446-public-api)".
- On success it prints, among the summary lines, the next step:

```
Ready to push:
  git push --force-with-lease origin <FEATURE_BRANCH>
```

## Notes

This command is one half of a pair. The companion `orfi-kit-enforce-sync.sh` is a `PreToolUse` hook on `Bash` calls that **blocks** any `git push` when the current branch is an epic-derived working branch (any prefix, but never `master` or `epic/*`) and its parent epic has moved ahead. The hook reads the same `.claude/hooks/state/parent-epic` file this command writes (or discovers the epic dynamically), then runs `git merge-base --is-ancestor origin/<epic> HEAD`; if the epic tip is not an ancestor of the working branch HEAD, the push is denied with a message telling you to run `/orfi-kit-sync-branch`. Running this command is what clears that block.
