---
name: orfi-kit-sync-master
description: Use when the user requests syncing an epic or standalone branch with master; known epic-derived working branches use sync-branch.
---

# Sync Master Workflow

Sync the current epic or standalone branch with origin/master and publish to that same branch. An epic branch is a supported source branch. This skill updates the source branch; it never pushes directly to master/main.

## 1. Classify the branch

Read the current branch and repository branch-parent evidence.

- Reject detached HEAD, master, and main before mutation; respect other protected destinations.
- Accept epic/* directly. Its prefix does not prohibit rebasing or require a merge.
- Route a working branch derived from an epic to orfi-kit-sync-branch for master -> epic -> working-branch synchronization. Do not skip its parent epic.
- Accept standalone branches with no epic parent. Ask only when parentage is genuinely unresolved; naming alone is insufficient.

## 2. Preserve local work and reconcile remote changes

Inspect status and staged/unstaged diffs. Preserve local, peer, untracked and secret-bearing work. Commit only authorized, reviewed files using explicit paths and repository naming conventions; never stage everything or create empty commits. Do not automatically stash, reset, restore or discard work.

Verify origin's destination without printing embedded credentials. Fetch fresh origin/master and the same-named remote branch when it exists; record the exact remote tip before integration. A fetch failure is not evidence that the branch is absent.

- Equal to the fetched tip or locally ahead: continue.
- Strictly behind: fast-forward the current branch to that tip.
- Diverged: preserve both histories and resolve the reconciliation decision before integration; do not overwrite peers.

## 3. Choose the integration strategy

Honor the repository's documented branch/merge policy and the user's explicit choice. Reuse a strategy already resolved in this session rather than asking again.

- Rebase is the default for an epic or standalone branch when no merge policy overrides it. If linear history or rebase-compatible integration is required, use git rebase origin/master.
- If the repository/branch policy or user explicitly requires merge-based synchronization, use git merge origin/master.
- Generic advice that all epics must merge or must never rebase is not a branch-protection rule. Choose from the actual policy and authorization above. Referenced naming conventions must not silently replace this decision.
- Before rewriting published history, preserve the current history in a verified recovery bundle or existing recovery ref. Obtain any explicit rewrite authorization required by higher guardrails; reuse prior authorization that still covers this branch/action. Do not create extra worktrees, branches or PRs as routine synchronization steps.

If origin/master is already an ancestor of HEAD, skip unnecessary integration. If a linear/rebase requirement is still unsatisfied, distinguish that remaining history work from ancestry synchronization; do not claim the branch meets that requirement merely because master is an ancestor. Do not rewrite descendant branches as part of this skill.

## 4. Resolve conflicts and verify

Read each conflicted file and surrounding code. Preserve master's production fixes and the source branch's feature behavior and acceptance criteria; integrate both intentions instead of blindly accepting one side. Stage only resolved paths and continue the active merge/rebase. For genuinely ambiguous intent, preserve the operation and request the specific missing decision; do not automatically abort or discard work.

Review the actual diff, and review range-diff/history evidence when commits were rewritten. Run repository-required checks appropriate to the changes. Report actual pass/fail/skip counts; stop publication on failures. Complete the permitted preservation, resolution and review work before requesting any remaining push approval.

## 5. Publish safely to the same branch

Recheck the source branch and explicit destination. Never use a bare push that may target an upstream epic or master.

- For a new branch or fast-forward update, use git push origin HEAD:refs/heads/<branch>.
- If already-published commits were rewritten, an epic and a standalone branch use the same authorized, exact-lease procedure:
  git push --force-with-lease=refs/heads/<branch>:<recorded-remote-tip> origin HEAD:refs/heads/<branch>
- Use this rewrite command only with the required explicit authorization and verified backup. Never use an unconditional force push. If the remote moved or the push is rejected, inspect and reconcile; do not silently fetch a new lease and overwrite it.
- If no publication is needed, report the no-op.

Report the verified master/source/remote revisions, chosen strategy, actual check results and any outstanding CI or integration-compatibility checks separately. An ancestry check or successful push does not establish passing CI, merge-queue acceptance or an actual merge.
