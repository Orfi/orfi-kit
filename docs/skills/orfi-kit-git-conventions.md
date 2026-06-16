# orfi-kit-git-conventions
> Required format for branch names, commit messages, and PR titles, plus the epic/story branching-with-worktrees workflow.

## What it does
Defines the conventions you follow whenever you touch version control: how to name a branch, how to write a commit message (with a fixed set of verbs), how to title and body a pull request, and an optional ticket ID reference scheme. It also specifies a full epic-scoped branching strategy — one feature branch and one worktree per story, a master → epic → feature sync cascade, and worktree pruning after merge.

## When it fires / how to invoke
Auto-triggers on any git operation: committing, creating branches, opening PRs, starting a new story under an epic, syncing branches (master → epic → feature), or closing an epic.

## Prerequisites
- A ticket ID if one exists — if you don't already know it, ask the user. A ticket ID is any project prefix followed by a number (e.g., `ORFI-123`, `ABC-456`). If there is no ticket ID, omit it from every format. **When a ticket ID is available, every commit, branch, and PR must reference it — no exceptions.**
- The epic/story branching section additionally requires: work organized as an **epic** containing multiple **stories**, an `origin` remote, and `epic/{EPIC-ID}-{name}` + `feature/{STORY-ID}-{name}` branch naming. If the project is a single-story change with no epic, skip that section and branch directly off master.

## Behavior / rules

### Branch names
Only applied when creating a *new* branch; if the current branch already exists, leave it as-is.
- Format: `{type}/{ticket-id}-{short-description}` — e.g. `feat/ORFI-61026-add-user-role-management`
- Without ticket: `{type}/{short-description}` — e.g. `fix/login-timeout-issue`
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `epic`

### Commit messages
- Format: `{type}({ticket-id}): {VERB}: description` — e.g. `feat(ORFI-61026): ADDED: user role management`
- Without ticket: `{type}: {VERB}: description` — e.g. `fix: FIXED: login timeout issue`
- Verbs:
  - **ADDED** — new functionality or files
  - **CHANGED** — modified without a clear improvement or fix (config changes, swapped implementations, updated defaults)
  - **IMPROVED** — changed with an overall improvement
  - **FIXED** — broken functionality corrected
  - **REMOVED** — functionality or files removed
  - **REFACTORED** — restructured without changing behavior
  - **UPDATED** — dependencies or versions bumped
  - **DEPRECATED** — marked for future removal
  - **MOVED** — files or code relocated between modules

### Pull requests
- Title: `{type}({ticket-id}): short description` (under 70 chars); without ticket `{type}: short description`
- Body uses a `## Summary` bullet section and a `## Test plan` checklist (`Tests pass`, `Manual verification: {steps}`).

### Branching strategy (epic-scoped)
- Branch roles: `master` is the protected, PR-only permanent trunk; `epic/{EPIC-ID}-{name}` is the integration branch for all stories under one epic (its own worktree, lives until the epic merges); `feature/{STORY-ID}-{name}` is one per story, derived from the epic branch (its own worktree, lives until the story merges into epic).
- Work NEVER happens directly on master or on the epic branch's worktree — only on a story feature branch's worktree.
- One worktree per branch; never share a worktree across stories. Worktree path pattern: `C:\repos\wt-{short-name}`.
- **Starting a story:** confirm the story ticket ID and parent epic branch, then `git worktree add -b feature/{STORY-ID}-{name} <path> origin/epic/{EPIC-ID}-{name}`, and `cd` in. This auto-sets the new branch's upstream to the *epic* (the start-point), which is wrong — fix it immediately so the feature branch tracks its own remote (`git branch --unset-upstream` then `git push -u origin feature/...`, or just push early with `git push -u origin feature/...`).
- **Carrying local shared state:** tracked files arrive with the checkout. State outside the repo at a fixed absolute path needs nothing (every worktree already reaches it). Gitignored state inside the worktree tree does not come with the checkout — if it must be shared, symlink it (Windows `mklink /J` for dirs, `mklink /H` for files) to a single source-of-truth copy. Only ever symlink gitignored items; never symlink tracked content. Determine which paths are which from the project's own onboarding/context docs — do not hardcode them.
- **Sync cadence (master → epic → feature):** run the two-step cascade at the start of each session, before any push to epic, before opening a story PR, and whenever master gains commits affecting files you touch. Step 1 (from epic worktree): `git fetch`, `git rebase origin/master`, push the epic. Step 2 (from story worktree): `git fetch`, `git rebase origin/epic/...`, `git push --force-with-lease origin feature/...`. Some epics override step 1 to *merge instead of rebase* — follow the project's onboarding docs when they specify a different epic-sync policy.
- **Opening the story PR (feature → epic):** sync the cascade, run the project quality gate (e.g. `/dod`), open PR with base = epic branch (never master). After merge, prune: `git worktree remove`, `git branch -D`, `git push origin --delete` the feature branch.
- **Closing the epic (epic → master):** only when all child stories are merged and closed in the tracker (e.g. `/epic-close`); final-sync master into epic, open PR with base = master, then prune the epic worktree and delete the epic branch local + remote.

### Guardrails
- Never commit to master directly, and never commit to the epic branch from its own worktree.
- Never open a story PR targeting master — base is always the epic branch.
- Never force-push the epic branch or master; `--force-with-lease` is only acceptable on an unmerged feature branch with no other collaborators.
- Never delete a feature branch or worktree until the merge is confirmed on the remote epic branch.
- Never skip the sync cascade before pushing to epic.
- One story = one branch = one worktree.

## Example
Starting a story off an epic, with the required upstream fix:

```bash
cd C:/repos/{main-repo}
git fetch origin
git worktree add -b feature/ORFI-123-add-login C:/repos/wt-ORFI-123-login origin/epic/ORFI-100-auth
# in the new worktree, fix the auto-set upstream:
git push -u origin feature/ORFI-123-add-login
```

A commit on that branch:

```
feat(ORFI-123): ADDED: login form and session handling
```

## Notes
- This skill works alongside `orfi-guardrails`, which enforces safe version-control practices project-wide.
- The sync cascade and worktree conventions reference project onboarding/context docs for project-specific paths and any per-epic merge-vs-rebase override; consult those rather than hardcoding.
