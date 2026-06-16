# orfi-kit-enforce-sync-hook

> Blocks `git push` from a `feature/*` branch when it hasn't been rebased on top of its parent `epic/*` branch.

## What it does

This is a global `PreToolUse` hook on `Bash` that intercepts `git push` commands run from a `feature/*` branch. Before the push goes through, it resolves the feature branch's parent epic branch and verifies that the epic's current tip is an ancestor of your feature `HEAD`. If the epic has moved ahead (for example, it was rebased on master) and your feature branch doesn't include those changes, the hook exits non-zero and blocks the push, telling you to sync first.

## When it fires / how to invoke

Passive — it runs automatically. It triggers on any `Bash` command containing `git push`, but only acts when the current worktree branch is `feature/*`. All other commands and branches pass straight through (exit 0). You don't invoke it directly; to resolve a block, run `/orfi-kit-sync-branch`.

## Prerequisites

- A branch named `feature/*` (the hook does nothing on other branches).
- An `origin` remote.
- At least one `origin/epic/*` branch to sync against — if none exists, the push is allowed.
- Optionally, a state file at `<worktree>/.claude/hooks/state/parent-epic` (written by `/orfi-kit-sync-branch`) naming the parent epic; without it the hook auto-discovers the parent.

## Behavior / rules

- Only `git push` commands are intercepted; everything else exits 0 immediately.
- Only `feature/*` branches are enforced; other branches exit 0.
- Parent epic resolution order:
  1. Read `<worktree>/.claude/hooks/state/parent-epic` if present.
  2. Otherwise, list remote `origin/epic/*` branches and pick the one whose tip is an ancestor of `HEAD` with the smallest commit distance (closest ancestor). The worktree root is `CLAUDE_PROJECT_DIR`, falling back to `$PWD`.
- If no epic branch can be resolved, there is nothing to enforce and the push is allowed.
- It runs `git fetch origin <epic>` to get the latest epic tip, then checks `git merge-base --is-ancestor origin/<epic> HEAD`.
- If the epic tip is NOT an ancestor of `HEAD`, the push is blocked (exit 1) with a message describing the required sync hierarchy: `origin/master → <epic> → <feature>`.
- If the check passes, it prints a confirmation and exits 0, letting the push proceed.

The intended sync order this hook guards (per Rule R7 for epic hierarchies) is: rebase `epic/*` on `origin/master`, rebase `feature/*` on `epic/*`, then push (with `--force-with-lease`).

## Example

You try to push your feature branch while its epic has been rebased on master:

```
$ git push
BLOCKED: Feature branch 'feature/login-form' is out of sync with 'epic/auth'.

The epic branch has been updated (rebased on master) and your feature branch
does not include those changes.

Run /orfi-kit-sync-branch to fix this:
  1. Rebase epic/auth on origin/master
  2. Rebase feature/login-form on epic/auth
  3. Then push with --force-with-lease

Sync hierarchy: origin/master → epic/auth → feature/login-form
```

After syncing, the push prints `Sync check passed: 'feature/login-form' is up to date with 'epic/auth'.` and proceeds.

## Notes

- Pairs with `/orfi-kit-sync-branch`, which performs the rebase steps and writes the `parent-epic` state file the hook reads.
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
