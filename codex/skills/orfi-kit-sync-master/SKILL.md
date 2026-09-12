---
name: orfi-kit-sync-master
description: Commit local changes, rebase on origin/master, and push safely.
---

# Sync Master Workflow (Codex version)

## 0. Verify branch eligibility

This skill rebases directly on `origin/master` and force-pushes — safe only for a standalone branch, dangerous for epic work.

```powershell
$branch = git branch --show-current
if ($branch -eq 'master' -or $branch -match '^epic/') { throw "ABORTED: /orfi-kit-sync-master rebases on master and force-pushes; it must not run on master or epic/* (current: $branch)" }
```

If the branch is derived from an epic (its parent is an `epic/*` branch — e.g. a `feature/`, `fix/`, `chore/` branch under an active epic), STOP and steer the user instead:

> This branch derives from an epic. Rebasing directly on origin/master would skip the epic and diverge from it. Use /orfi-kit-sync-branch (master -> epic -> this branch) instead of /orfi-kit-sync-master.

Only continue for a standalone branch that legitimately rebases directly on master (no epic parent). If unsure whether an epic parent exists, ask the user.

## 1. Check working tree

```powershell
git status --short
```

If there are changes, stage and commit using `orfi-kit-git-conventions`.
If clean, continue without creating an empty commit.

## 2. Rebase on latest master

```powershell
git fetch origin master
git rebase origin/master
```

Always use rebase (not merge) for this workflow.

## 3. Conflict handling

If conflicts occur:
1. Resolve each conflicted file while preserving intent from both sides.
2. Run project checks/tests appropriate to changed files.
3. Stage resolved files.
4. Continue:

```powershell
git rebase --continue
```

If conflict intent is ambiguous, abort and ask user:

```powershell
git rebase --abort
```

## 4. Push

After a successful rebase, push with lease protection:

```powershell
git push origin HEAD --force-with-lease
```
