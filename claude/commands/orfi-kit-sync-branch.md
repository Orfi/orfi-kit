---
name: orfi-kit-sync-branch
description: Sync a feature branch with its parent epic and master before pushing. Detects whether the epic uses merge or rebase strategy and applies it correctly.
disable-model-invocation: true
---


# orfi-kit-sync-branch

Sync a feature branch through its full parent hierarchy before pushing:
`origin/master` → `epic/PANV-*` → `feature/PANV-*`

Run this before every `git push` on a feature branch that lives under an epic branch.

You are executing the sync-branch workflow. Complete every step in order. Do not skip steps. Do not ask for confirmation unless a conflict requires a decision.

## Step 1: Verify current branch

Determine the branch for the current worktree:

```bash
git branch --show-current
```

The branch MUST match `feature/PANV-*`. If it does not, abort immediately:

> ABORTED: /orfi-kit-sync-branch only runs on feature/PANV-* branches. Current branch: {branch}
> Switch to your feature branch and retry.

Record `FEATURE_BRANCH` and `FEATURE_WORKTREE` (the current directory) for use in later steps.

## Step 2: Resolve the parent epic branch

Check the state file first:

```bash
cat .claude/hooks/state/parent-epic 2>/dev/null
```

If the state file is present and non-empty, use that value as `EPIC_BRANCH`.

If missing or empty, discover it dynamically:

```bash
git fetch origin --prune -q
git branch -r | grep "origin/epic/PANV-" | sed 's|.*origin/||' | sort
```

If multiple epic branches exist, find the one whose tip is the closest ancestor to HEAD:

```bash
# For each candidate:
git merge-base HEAD origin/<candidate>
```

Select the candidate with the merge-base commit closest to the current HEAD. If you cannot determine the parent automatically, ask the user:

> Which epic branch is the parent of {FEATURE_BRANCH}? (e.g. epic/PANV-60446-public-api)

## Step 3: Locate the epic worktree

Epic worktrees follow the convention `C:/repos/wt-panviva-{epic-id}-{epic-slug}`.

Example: `epic/PANV-60446-public-api` → `C:/repos/wt-panviva-60446-public-api`

Verify it exists:

```bash
git worktree list
```

Extract the path for `EPIC_BRANCH` from the output. If the worktree is not listed, abort:

> ABORTED: Epic worktree for {EPIC_BRANCH} not found.
> Expected path: C:/repos/wt-panviva-{epic-id}-{slug}
> Create it with: git worktree add <path> {EPIC_BRANCH}

Record the path as `EPIC_WORKTREE`.

## Step 4: Fetch latest from origin

```bash
git fetch origin --prune
```

## Step 5: Detect epic sync strategy and sync epic with master

Before syncing, determine whether the epic branch has historically been synced via **merge** or **rebase**. Do not assume — check the evidence.

```bash
cd <EPIC_WORKTREE>
git log --oneline --merges -5 origin/<EPIC_BRANCH>
```

Also check the current HEAD commit:

```bash
git cat-file -p origin/<EPIC_BRANCH> | grep "^parent" | wc -l
```

**Decision rules:**

| Evidence | Strategy |
|----------|-----------|
| Merge commits exist in epic history (`--merges` returns results) | **MERGE** |
| Epic HEAD has 2 parents (`parent` count = 2) | **MERGE** |
| No merge commits, all linear history | **REBASE** |

### If strategy = MERGE

```bash
cd <EPIC_WORKTREE>
git merge origin/master
git push origin <EPIC_BRANCH>
```

Use a regular push (no `--force-with-lease`) — merge commits do not rewrite history.

**If merge conflicts occur:** STOP. Report:

> CONFLICT: Merge of origin/master into {EPIC_BRANCH} failed.
> Conflicting files: {list files}
>
> Resolve conflicts in {EPIC_WORKTREE}, then run:
>   git merge --continue
> Then run /orfi-kit-sync-branch again to complete the sync.

### If strategy = REBASE

```bash
cd <EPIC_WORKTREE>
git rebase origin/master
git push --force-with-lease origin <EPIC_BRANCH>
```

**If rebase conflicts occur:** STOP. Report:

> CONFLICT: Rebase of {EPIC_BRANCH} on origin/master failed.
> Conflicting files: {list files}
>
> Resolve conflicts in {EPIC_WORKTREE}, then run:
>   git rebase --continue
> Then run /orfi-kit-sync-branch again to complete the sync.

Record the detected strategy as `EPIC_SYNC_STRATEGY` (either `merge` or `rebase`) for use in the completion report.

## Step 6: Rebase feature branch on epic

```bash
cd <FEATURE_WORKTREE>
git rebase <EPIC_BRANCH>
```

**If rebase conflicts occur:** STOP. Report:

> CONFLICT: Rebase of {FEATURE_BRANCH} on {EPIC_BRANCH} failed.
> Conflicting files: {list files}
>
> Resolve conflicts in {FEATURE_WORKTREE}, then run:
>   git rebase --continue
> Then run /orfi-kit-sync-branch again to complete the sync.

## Step 7: Record sync state

```bash
echo "<EPIC_BRANCH>" > .claude/hooks/state/parent-epic
date -u +%Y-%m-%dT%H:%M:%SZ > .claude/hooks/state/last-sync-timestamp
```

## Step 8: Report completion

```
✓ orfi-kit-sync-branch complete
  Feature         : <FEATURE_BRANCH>
  Epic            : <EPIC_BRANCH>
  Epic sync via   : <EPIC_SYNC_STRATEGY> ✓
  Epic pushed     : ✓
  Feature rebased : on <EPIC_BRANCH> ✓

Ready to push:
  git push --force-with-lease origin <FEATURE_BRANCH>
```
