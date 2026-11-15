# orfi-kit-sync-master

Synchronize the current **epic or standalone branch** with `origin/master` and publish to that same branch. Master/main remain protected destinations.

## Invocation and runtime sources

- Claude Code and OpenCode: `/orfi-kit-sync-master`. Both use [the Claude command](../../claude/commands/orfi-kit-sync-master.md).
- GitHub Copilot CLI: `/orfi-kit-sync-master` through [its skill](../../copilot/skills/orfi-kit-sync-master/SKILL.md).
- Codex: `$orfi-kit-sync-master` through [its skill](../../codex/skills/orfi-kit-sync-master/SKILL.md). Existing invocation-policy metadata is preserved.

## Eligible branches

| Current branch | Behavior |
| --- | --- |
| `epic/*` | Sync directly with master; the epic prefix does not prohibit rebase or require merge |
| Standalone branch without an epic parent | Sync directly with master |
| Working branch derived from an epic | Use [orfi-kit-sync-branch](orfi-kit-sync-branch.md) for master -> epic -> working branch |
| Detached HEAD, `master`, or `main` | Reject before mutation |

Parentage comes from repository evidence, not only the branch name.

## Integration and publication

1. Preserve local, peer, untracked and secret-bearing work. Commit only authorized reviewed paths; do not automatically stage everything, stash, reset, discard or create empty commits.
2. Fetch fresh master and the same-named remote branch, recording its exact tip. Fast-forward when behind; preserve and reconcile divergent histories rather than overwriting peers. A fetch failure does not establish remote absence.
3. Honor the documented repository/branch strategy or explicit user choice. Default to **rebase for epic and standalone branches**; use merge when the established policy requires it. Linear-history/rebase requirements must be respected.
4. Before rewriting published history, preserve a verified recovery bundle/ref and obtain the explicit authorization required by the guardrails. Reuse prior covering authorization without asking again. No extra worktree, branch or PR is a routine requirement.
5. Resolve conflicts by preserving master's production fixes and the branch's feature behavior/acceptance criteria. Review actual changes and rewritten history, then run the required targeted checks. Preserve ambiguous operations for the missing decision; do not automatically abort/discard.
6. Publish explicitly to `HEAD:refs/heads/<branch>`. Use a normal push for a new branch or fast-forward update. For an authorized rewrite, use `git push --force-with-lease=refs/heads/<branch>:<recorded-remote-tip> origin HEAD:refs/heads/<branch>`. Never use unconditional force or silently refresh a rejected lease.

## Completion limits

Master being an ancestor establishes ancestry synchronization only. It does not prove linear-history/rebase compatibility, passing CI, queue acceptance or an actual merge. Report these separately with the actual check results and revision bindings. This command does not rewrite descendant feature branches.

## Installation and updates

Both [install.sh](../../install.sh) and [install.ps1](../../install.ps1) already install these sources and replace existing command/skill copies on reinstall. OpenCode receives the shared Claude command; Copilot and Codex receive their own skill directories. No installer routing change is needed for this update. Rerun the installer for the selected runtimes to refresh copied installations; linked installations follow repository changes.
