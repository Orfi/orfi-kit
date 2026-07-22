# orfi-kit-sync-master

> Commit local changes, rebase the current branch on the latest master, and force-push — keeping a clean linear history.

## What it does

Brings your current feature branch up to date with master. It commits any outstanding local work, fetches the latest master, rebases your branch on top of it (never merges), resolves any conflicts while preserving both sides' intent, and pushes the result back to the remote.

## How to invoke

Run the slash command:

```
/orfi-kit-sync-master
```

This command does not auto-trigger — it is explicitly invoked by you (`disable-model-invocation` is set).

## Prerequisites

- An `origin` remote with a `master` branch (the command runs `git fetch origin master` and `git rebase origin/master`).
- A branch with an upstream/remote tracking branch to push to.
- The current branch must be eligible: **not** `master`, **not** an `epic/*` branch, and **not** an epic-derived working branch (those are steered to `/orfi-kit-sync-branch` — see below).

## Behavior / rules

1. **Verify branch eligibility** — runs `git branch --show-current`. Because this command rebases directly on `origin/master` and force-pushes, it is only safe for a standalone branch:
   - **Aborts** if the branch is `master` or matches `epic/*` — a rebase-and-force-push must never touch a protected or epic branch.
   - **Steers to `/orfi-kit-sync-branch`** if the branch is derived from an epic (its parent is an `epic/*` branch — e.g. a `feature/`, `fix/`, or `chore/` branch under an active epic). Rebasing such a branch directly on `origin/master` would skip the epic and diverge from it, so the command stops and points you at the epic-aware workflow (`master → epic → this branch`) instead.
   - Continues only for a standalone branch with no epic parent. If it cannot tell whether an epic parent exists, it asks you.
2. **Check for uncommitted changes** — runs `git status`. If there are staged or unstaged changes, it uses the `orfi-kit-git-conventions` skill to stage and commit them. If the working tree is clean, it skips committing and never creates an empty commit.
3. **Fetch and rebase on master** — runs `git fetch origin master` then `git rebase origin/master`. Always rebases, never merges, to keep history linear and avoid merge commits.
4. **Handle rebase conflicts** (if any):
   - Reads each conflicted file to understand both what master changed and what your branch changed.
   - Resolves by preserving the intent of both sides: do not break production code (master's changes landed for a reason — bug fixes, security patches, schema changes), and do not break your branch's work. If both sides touched the same logic, integrates them so both changes take effect.
   - Runs any available linters or type checks after resolving, then stages the resolved files and runs `git rebase --continue`.
   - If a conflict is too ambiguous to resolve confidently, runs `git rebase --abort` and asks you before proceeding.
5. **Push to remote** — after a rebase a force push is required, so it runs `git push origin HEAD --force-with-lease`. It uses `--force-with-lease` (never plain `--force`) to avoid overwriting remote changes made by others.

## Notes

- Commits are made through the `orfi-kit-git-conventions` skill, so they follow the kit's commit-message format.
