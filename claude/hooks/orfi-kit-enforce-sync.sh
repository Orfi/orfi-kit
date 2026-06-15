#!/bin/bash
# ENFORCEMENT HOOK: Block pushes from a feature branch not synced with its parent epic
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PreToolUse on Bash (filtered to git push on feature/PANV-* branches)
# Exit non-zero = BLOCK the push
#
# Sync order (Rule R7 extension for epic branch hierarchies):
#   1. Rebase epic/PANV-* on origin/master
#   2. Rebase feature/PANV-* on epic/PANV-*
#   3. Then push
#
# Run /orfi-kit-sync-branch to perform these steps automatically.

COMMAND="${TOOL_INPUT_command:-}"

# Only intercept git push commands
case "$COMMAND" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

# Resolve the worktree root
WORKTREE="${CLAUDE_PROJECT_DIR:-$PWD}"

# Determine the current branch of this worktree
CURRENT_BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null)

# Only apply to feature/PANV-* branches
case "$CURRENT_BRANCH" in
  feature/PANV-*) ;;
  *) exit 0 ;;
esac

# --- Resolve parent epic branch ---

EPIC_BRANCH=""
STATE_FILE="$WORKTREE/.claude/hooks/state/parent-epic"

# Try state file first (written by /orfi-kit-sync-branch)
if [ -f "$STATE_FILE" ]; then
  EPIC_BRANCH=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')
fi

# If not in state file, discover from remote branches
if [ -z "$EPIC_BRANCH" ]; then
  EPIC_BRANCHES=$(git -C "$WORKTREE" branch -r 2>/dev/null \
    | grep "origin/epic/PANV-" \
    | sed 's|.*origin/||' \
    | tr -d ' ')

  if [ -z "$EPIC_BRANCHES" ]; then
    # No epic branches found — cannot enforce. Allow push.
    exit 0
  fi

  # Pick the epic whose tip is the closest ancestor to HEAD
  BEST_EPIC=""
  BEST_DEPTH=999999
  for CANDIDATE in $EPIC_BRANCHES; do
    if git -C "$WORKTREE" merge-base --is-ancestor "origin/$CANDIDATE" HEAD 2>/dev/null; then
      DEPTH=$(git -C "$WORKTREE" rev-list --count "origin/$CANDIDATE"..HEAD 2>/dev/null || echo 999999)
      if [ "$DEPTH" -lt "$BEST_DEPTH" ]; then
        BEST_DEPTH=$DEPTH
        BEST_EPIC=$CANDIDATE
      fi
    fi
  done
  EPIC_BRANCH="$BEST_EPIC"
fi

# If still no epic branch resolved, nothing to enforce
if [ -z "$EPIC_BRANCH" ]; then
  exit 0
fi

# --- Fetch latest tip of the epic branch ---
git -C "$WORKTREE" fetch origin "$EPIC_BRANCH" --quiet 2>/dev/null || true

# --- Check: epic tip must be an ancestor of feature HEAD ---
if ! git -C "$WORKTREE" merge-base --is-ancestor "origin/$EPIC_BRANCH" HEAD 2>/dev/null; then
  echo "BLOCKED: Feature branch '$CURRENT_BRANCH' is out of sync with '$EPIC_BRANCH'.

The epic branch has been updated (rebased on master) and your feature branch
does not include those changes.

Run /orfi-kit-sync-branch to fix this:
  1. Rebase $EPIC_BRANCH on origin/master
  2. Rebase $CURRENT_BRANCH on $EPIC_BRANCH
  3. Then push with --force-with-lease

Sync hierarchy: origin/master → $EPIC_BRANCH → $CURRENT_BRANCH"
  exit 1
fi

echo "Sync check passed: '$CURRENT_BRANCH' is up to date with '$EPIC_BRANCH'."
exit 0
