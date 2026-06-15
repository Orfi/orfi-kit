---
name: orfi-kit-sync-master
description: Commit local changes, rebase on origin/master, and push safely.
disable-model-invocation: true
---

# Sync Master Workflow (Copilot version)

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
