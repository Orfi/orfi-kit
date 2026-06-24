---
name: orfi-kit-git-conventions
description: Conventions for git commit messages, branch names, pull request titles, and the epic/story branching strategy with worktrees. Use this skill whenever committing, creating branches, opening PRs, starting a new story under an epic, syncing branches (master → epic → feature), or closing an epic. It defines the required format including commit verbs (ADDED, FIXED, IMPROVED, etc.), optional ticket ID references, and the full feature-branch-per-story workflow with worktree pruning.
---
# Git Conventions

These conventions define how to format branch names, commit messages, and pull request titles, plus the branching strategy for epic-scoped work.

## Ticket ID

If you don't already know the ticket ID, ask the user for it. A ticket ID can be any project prefix followed by a number (e.g., ORFI-123, ABC-456, PROJ-789). If there is no ticket ID, omit it from all formats below.

## Branch Name

Only apply these conventions when creating a new branch. If the current branch already exists, leave it as-is and move on to commits and PRs.

Format: `{type}/{ticket-id}-{short-description}`
Without ticket: `{type}/{short-description}`

Examples:
- `feat/ORFI-61026-add-user-role-management`
- `fix/login-timeout-issue`

Types: feat, fix, refactor, test, docs, chore, epic

## Commit Messages

Format: `{type}({ticket-id}): {VERB}: description`
Without ticket: `{type}: {VERB}: description`

Examples:
- `feat(ORFI-61026): ADDED: user role management`
- `fix: FIXED: login timeout issue`

### Commit Verbs

Use one of these verbs to describe what happened:

- **ADDED**: New functionality or files were added
- **CHANGED**: Functionality was modified without a clear improvement or fix — e.g., config changes, swapped implementations, updated defaults
- **IMPROVED**: Functionality was changed resulting in an overall improvement
- **FIXED**: Broken functionality was corrected
- **REMOVED**: Functionality or files were removed
- **REFACTORED**: Code was restructured without changing behavior
- **UPDATED**: Dependencies or versions were bumped
- **DEPRECATED**: Functionality was marked for future removal
- **MOVED**: Files or code were relocated between modules

## Pull Request

Title format: `{type}({ticket-id}): short description` (under 70 chars)
Without ticket: `{type}: short description`

Examples:
- `feat(ORFI-61026): Add user role management`
- `fix: Resolve login timeout issue`

Body format:
```
## Summary
- Bullet point 1
- Bullet point 2

## Test plan
- [ ] Tests pass
- [ ] Manual verification: {steps}
```

## General Rule

If a ticket ID is available, every commit, branch, and PR must reference it — no exceptions.

## Branching Strategy (epic-scoped work)

Apply this section when work is organized under an **epic** that contains multiple **stories**. Each story gets its own feature branch and its own worktree. Stories merge into the epic branch. The epic merges into master only when all its stories are done.

If the project is a single-story change with no epic, skip this section — just create a feature branch directly off master using the formats above.

### Roles of each branch

| Branch | Purpose | Lifespan |
|---|---|---|
| `master` | Protected trunk. PRs only. | Permanent |
| `epic/{EPIC-ID}-{name}` | Integration branch for all stories under one epic. Has its own worktree. | Until epic is merged |
| `feature/{STORY-ID}-{name}` | One per story. Derived from the epic branch. Has its own worktree. | Until story is merged into epic |

Work NEVER happens directly on `master` or the epic branch's worktree. It happens on a story feature branch's worktree.

### Worktree conventions

- Worktree path: `C:\repos\wt-{short-name}` — derive `{short-name}` from the ticket ID + a brief slug (one for the epic worktree, one per story worktree).
- One worktree per branch. Never share a worktree across stories.
- After a story is merged, prune the worktree AND delete the branch (local + remote).

### Starting a new story

1. Confirm the story's ticket ID and its parent epic branch.
2. From the main checkout, create the feature branch off the latest epic branch, in a new worktree:
   ```bash
   cd C:/repos/{main-repo}
   git fetch origin
   git worktree add -b feature/{STORY-ID}-{name} C:/repos/wt-{story-short-name} origin/epic/{EPIC-ID}-{name}
   ```
3. `cd` into the new worktree. All subsequent work happens there.
4. **Fix the upstream.** `git worktree add -b <branch> <path> origin/epic/...` makes git auto-set the new branch's upstream to **`origin/epic/...`** (it defaults the upstream to the start-point). That is WRONG for this model — a feature branch's upstream must be its OWN remote (`origin/feature/{STORY-ID}-{name}`), not the epic. Left as-is, a bare `git push`/`git pull`/`git status` resolves against the epic. Fix it immediately, one of two ways:
   - `git branch --unset-upstream` now, then `git push -u origin feature/{STORY-ID}-{name}` on the first push (sets the correct upstream), **or**
   - just push early with `git push -u origin feature/{STORY-ID}-{name}`, which overwrites the bad upstream with the correct one.
   The feature↔epic relationship is a **sync operation you run** (the cascade below), NOT the branch's tracking config.
5. Carry local shared state into the new worktree if needed (see below).
6. Every commit on this branch references the story ticket ID per the commit format above.

### Carrying local shared state into a new worktree

Tracked files arrive automatically via the branch checkout. Two kinds of state do NOT, and they are handled differently — distinguish them before doing anything:

1. **State that lives OUTSIDE the repo, at a fixed absolute path** (e.g. a sibling directory holding credentials, fixtures, or onboarding docs that was deliberately kept out of git). Every worktree already reaches it at the same absolute path — **do nothing**. Do not symlink it; there is nothing to carry. (If code or tests reference it, they use the absolute path or a copy step, which is identical across worktrees.)

2. **Gitignored state that lives INSIDE the worktree tree** (e.g. a local `.env`, a tool's working DB, machine-local caches). This does not come with the checkout. If it must be shared across worktrees rather than regenerated per worktree, symlink it from the new worktree to a single source-of-truth copy:

```bash
# From the new worktree (paths are illustrative — substitute your own)
# Windows — `mklink /J` for directories (junction, no admin), `mklink /H` for files.
cmd //c "mklink /J <in-tree-dir> <absolute-path-to-source-copy>"
cmd //c "mklink /H <in-tree-file> <absolute-path-to-source-file>"
```

Rules:
- First decide which kind it is. Only kind 2 needs action. Most shared project state is kind 1 — leave it alone.
- Symlink ONLY gitignored items. Never symlink a tracked file or directory — git will see a symlink where content belongs and corrupt the branch. (The kit pointer `.orfi-kits/` is tracked, so it propagates via the branch checkout — never symlink it.)
- Reads/writes through the symlink land in the shared copy, so all worktrees see the same live state.
- When pruning the worktree at end-of-story, the symlinks go with it; the underlying shared copy is untouched.

> Determine the specific paths and which items are kind 1 vs kind 2 from the project's own onboarding/context docs — do not hardcode them here.

### Sync cadence while working on a story

Two-step cascade: **master → epic → feature**. Run this:
- At the start of each session.
- Before any push to the epic branch.
- Before opening a story PR.
- Whenever master has new commits that affect files you're touching.

```bash
# Step 1: pull master into the epic branch (from the epic worktree)
cd C:/repos/wt-{epic-worktree}
git fetch origin
git rebase origin/master
git push origin epic/{EPIC-ID}-{name}

# Step 2: pull epic into the feature branch (from the story worktree)
cd C:/repos/wt-{story-worktree}
git fetch origin
git rebase origin/epic/{EPIC-ID}-{name}
git push --force-with-lease origin feature/{STORY-ID}-{name}
```

> **Project note:** some epics override the master→epic step to use **merge, not rebase** (e.g. long-lived epics where rebasing hundreds of commits is impractical, or where the epic must never be force-pushed). Follow the project's onboarding/context docs when they specify a different epic-sync policy; the rebase shown here is the default for ordinary feature branches.

Never force-push the epic branch or master. `--force-with-lease` is only acceptable on a feature branch that is not yet merged and has no other collaborators.

### Opening the story PR (feature → epic)

1. Run the sync cascade so the feature branch is current with epic.
2. Run the project's full quality gate (e.g. `/dod`).
3. Open PR with base = `epic/{EPIC-ID}-{name}`, head = `feature/{STORY-ID}-{name}`. **Not** base=master.
4. After merge, prune:
   ```bash
   cd C:/repos/{main-repo}
   git worktree remove C:/repos/wt-{story-worktree}
   git branch -D feature/{STORY-ID}-{name}
   git push origin --delete feature/{STORY-ID}-{name}
   ```

### Closing the epic (epic → master)

Only when ALL stories under the epic are merged and the epic is truly done:

1. Verify every child story is closed in the tracker (e.g. `/epic-close`).
2. Final sync: rebase latest master into the epic branch.
3. Open PR with base = `master`, head = `epic/{EPIC-ID}-{name}`.
4. After merge, prune the epic worktree and delete the epic branch (local + remote).

### Guardrails

- Never commit to master directly. Never commit to the epic branch from its own worktree — work happens on feature branches.
- Never open a story PR targeting master. Base is always the epic branch.
- Never delete a feature branch or its worktree until the merge is confirmed on the remote epic branch.
- Never skip the sync cascade before pushing to epic — stale feature branches cause integration-time merge conflicts.
- One story = one branch = one worktree. Multi-story branches break traceability.
