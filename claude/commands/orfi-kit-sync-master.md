---
name: orfi-kit-sync-master
description: Commit, rebase on master, and push current branch.
disable-model-invocation: true
---

# Sync Master Workflow

This skill commits local changes, rebases on the latest master, and pushes. The goal is to keep the current feature branch up to date with master while preserving a clean linear history.

## Steps

### 0. Verify branch eligibility

Determine the current branch:

```bash
git branch --show-current
```

- **Abort** if the branch is `master` or matches `epic/*` — this skill rebases-and-force-pushes, which must never touch a protected or epic branch:

  > ABORTED: /orfi-kit-sync-master rebases on master and force-pushes; it must not run on master or epic/* branches. Current branch: {branch}

- **If the branch is derived from an epic** (its parent is an `epic/*` branch, e.g. a `feature/`, `fix/`, `chore/` branch under an active epic), STOP and steer the user to the epic-aware skill instead:

  > This branch derives from an epic. Rebasing directly on origin/master would skip the epic and diverge from it. Use /orfi-kit-sync-branch (master → epic → this branch) instead of /orfi-kit-sync-master.

  Only continue past this step for a standalone branch that legitimately rebases directly on master (no epic parent). If unsure whether an epic parent exists, ask the user.

### 1. Check for uncommitted changes

Run `git status` to see if there are staged or unstaged changes.

- **If there are changes to commit:** Use the `orfi-kit-git-conventions` skill to stage and commit them before proceeding.
- **If the working tree is clean:** Skip straight to step 2 — do not create an empty commit.

### 2. Fetch and rebase on master

```
git fetch origin master
git rebase origin/master
```

**Critical: Always use `rebase`, not `merge`.** This keeps the branch history linear and avoids unnecessary merge commits.

### 3. Handle rebase conflicts (if any)

If the rebase produces conflicts:

1. Read each conflicted file and understand both sides — what master changed and what our branch changed.
2. Resolve conflicts by preserving the intent of both sides. The priorities are:
   - **Do not break production code** — master's changes landed there for a reason (bug fixes, security patches, schema changes). Respect them.
   - **Do not break our branch's code** — our feature work matters too. Don't just accept theirs and throw away our changes.
   - If both sides modified the same logic, integrate them so both changes take effect. Read the surrounding code for context on what each side was trying to accomplish.
3. After resolving all conflicts, run any available linters or type checks to verify nothing is broken.
4. Stage the resolved files and run `git rebase --continue`.
5. If a conflict is too ambiguous to resolve confidently (e.g. two competing rewrites of the same function with unclear intent), run `git rebase --abort` and ask the user before proceeding.

### 4. Push to remote

Push the current branch to its remote tracking branch. After a rebase, a force push is needed:

```
git push origin HEAD --force-with-lease
```

Use `--force-with-lease` (not `--force`) to protect against overwriting remote changes made by others.