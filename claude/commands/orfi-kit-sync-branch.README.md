# orfi-kit-sync-branch — feature notes

Keeps a `feature/PANV-*` branch properly synced with its parent `epic/PANV-*` branch before every push.

> Salvaged from the retired `sync-branch/` package. Manual-install steps were removed — installation is the kit installer's job (created later). This file documents *why* the command + hook exist and *how* they work.

## Why this exists

When working in a two-level branch hierarchy (`master → epic → feature`), syncing the feature directly to master is not enough. The epic branch may have been rebased on a newer master, making the feature branch diverge from it. This causes conflicts and surprises when the feature is eventually merged back into the epic.

The correct sync order is:

```
1. Rebase epic/PANV-* on origin/master
2. Push epic with --force-with-lease
3. Rebase feature/PANV-* on the updated epic
```

## The two pieces

| File | What it is |
|------|-----------|
| `orfi-kit-sync-branch.md` | A slash command (`/orfi-kit-sync-branch`) that runs the full sync automatically |
| `../hooks/orfi-kit-enforce-sync.sh` | A `PreToolUse` hook that **blocks** `git push` if the feature branch is out of sync with its parent epic |

## Usage

### Running the sync manually

From any session where the current worktree is on a `feature/PANV-*` branch:

```
/orfi-kit-sync-branch
```

The command will:

1. Confirm you are on a `feature/PANV-*` branch
2. Discover the parent `epic/PANV-*` branch (from a state file or by scanning remote branches)
3. Locate the epic worktree at `C:/repos/wt-panviva-{epic-id}-{slug}`
4. Fetch `origin`
5. Rebase the epic on `origin/master` and force-push it
6. Rebase the feature on the updated epic
7. Write `.claude/hooks/state/parent-epic` so the push hook knows which epic to check against
8. Report ready-to-push status

### Automatic enforcement on push

Once the hook is wired in, any `git push` run while on a `feature/PANV-*` branch is checked automatically. If the epic branch has moved ahead of the feature branch, the push is **blocked** with a clear message telling you to run `/orfi-kit-sync-branch`.

## How it works

### `orfi-kit-sync-branch.md`

A command file. When invoked as `/orfi-kit-sync-branch`, the runtime reads the markdown and executes the steps as instructions. The command uses `git merge-base` to find the closest ancestor epic branch, handles conflict detection, detects the epic's merge-vs-rebase strategy, and writes a state file for the push hook.

### `orfi-kit-enforce-sync.sh`

A bash script wired as a `PreToolUse` hook on `Bash` tool calls. It:

1. Ignores all commands that are not `git push`
2. Ignores branches that do not match `feature/PANV-*`
3. Reads the parent epic from `.claude/hooks/state/parent-epic` (written by `/orfi-kit-sync-branch`) or discovers it dynamically from remote branches
4. Fetches the latest tip of the epic branch
5. Runs `git merge-base --is-ancestor origin/<epic> HEAD` — if the epic tip is not an ancestor of the feature HEAD, the push is blocked

## Assumptions

- Branch naming: `feature/PANV-{id}-{name}` and `epic/PANV-{id}-{name}`
- Epic worktrees live at: `C:/repos/wt-panviva-{epic-id}-{slug}`
- Each feature branch has exactly one parent epic branch
- `git fetch` is available and the remote is named `origin`
