# orfi-kit-enforce-sync-hook

> Blocks `git push` from an epic-derived working branch (any prefix) when it hasn't been rebased on top of its parent `epic/*` branch.

## What it does

This is a global `PreToolUse` hook on `Bash` that intercepts `git push` commands run from an epic-derived working branch (any prefix — `feature/`, `fix/`, `chore/`, etc.). Before the push goes through, it resolves the working branch's parent epic branch and verifies that the epic's current tip is an ancestor of your working branch `HEAD`. If the epic has moved ahead (for example, it was rebased on master) and your working branch doesn't include those changes, the hook exits non-zero and blocks the push, telling you to sync first.

## When it fires / how to invoke

Passive — it runs automatically. It triggers on any `Bash` command containing `git push`, but only acts when the current worktree branch is an epic-derived working branch (any prefix). It ignores `master` and `epic/*` branches. All other commands and those branches pass straight through (exit 0). You don't invoke it directly; to resolve a block, run `/orfi-kit-sync-branch`.

## Prerequisites

- Nothing external. The hook reads its payload with `jq` when it is on PATH and falls back to `sed` otherwise, so no tool has to be installed.
- An epic-derived working branch (any prefix except `master` / `epic/*`; the hook does nothing on those).
- An `origin` remote.
- At least one `origin/epic/*` branch to sync against — if none exists, the push is allowed.
- Optionally, a state file at `<worktree>/.claude/hooks/state/parent-epic` (written by `/orfi-kit-sync-branch`) naming the parent epic; without it the hook auto-discovers the parent.

## Behavior / rules

- The `git push` command is read from the `PreToolUse` JSON payload on **stdin**, at `.tool_input.command`.

  This is worth stating because it was wrong for the hook's entire life: the command used to be read from a `TOOL_INPUT_command` environment variable that the harness never sets. It was therefore always empty, the `git push` case never matched, and **the hook had never blocked a single push** while appearing to be correctly wired. If you write another hook, take the payload from stdin.

  Parsing uses `jq` when present and `sed` otherwise, per the repo rule that a missing tool must never be the reason a hook stops checking. A payload that cannot be parsed says so on **stderr** and lets the call through — refusing to parse is not grounds to block a push, but staying silent about it is how a broken guardrail passes for a working one.

- Only `git push` commands are intercepted; everything else exits 0 immediately.
- Only epic-derived working branches (any prefix) are enforced; `master`, `epic/*`, and detached HEAD exit 0.
- Parent epic resolution order:
  1. Read `<worktree>/.claude/hooks/state/parent-epic` if present.
  2. Otherwise, list remote `origin/epic/*` branches and pick the one whose tip is an ancestor of `HEAD` with the smallest commit distance (closest ancestor). The worktree root is `CLAUDE_PROJECT_DIR`, falling back to `$PWD`.
- If no epic branch can be resolved, there is nothing to enforce and the push is allowed.
- It runs `git fetch origin <epic>` to get the latest epic tip, then checks `git merge-base --is-ancestor origin/<epic> HEAD`.
- If the epic tip is NOT an ancestor of `HEAD`, the push is blocked (exit 1) with a message describing the required sync hierarchy: `origin/master → <epic> → <working branch>`.
- If the check passes, it prints a confirmation and exits 0, letting the push proceed.

The intended sync order this hook guards (per Rule R7 for epic hierarchies) is: rebase `epic/*` on `origin/master`, rebase the working branch on `epic/*`, then push (with `--force-with-lease`).

## Example

You try to push your working branch (here a `fix/*` branch) while its epic has been rebased on master:

```
$ git push
BLOCKED: Working branch 'fix/ORFI-62593-null-check' is out of sync with 'epic/auth'.

The epic branch has been updated (rebased on master) and your working branch
does not include those changes.

Run /orfi-kit-sync-branch to fix this:
  1. Rebase epic/auth on origin/master
  2. Rebase fix/ORFI-62593-null-check on epic/auth
  3. Then push with --force-with-lease

Sync hierarchy: origin/master → epic/auth → fix/ORFI-62593-null-check
```

After syncing, the push prints `Sync check passed: 'fix/ORFI-62593-null-check' is up to date with 'epic/auth'.` and proceeds.

## Notes

- Pairs with `/orfi-kit-sync-branch`, which performs the rebase steps and writes the `parent-epic` state file the hook reads.
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
