#!/bin/bash
# ENFORCEMENT HOOK: Block pushes from an epic-derived working branch not synced with its parent epic
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PreToolUse on Bash (filtered to git push on epic-derived working
#           branches — any prefix except master/epic/*)
# Platform: exports ORFI_HOOK_PLATFORM=claude|opencode|copilot. Claude and
#           opencode share the exit-code contract below — non-zero blocks.
#           Copilot PreToolUse takes a deny decision JSON on stdout instead of an
#           exit code, so this hook emits that (see the block section).
# Exit non-zero = BLOCK the push (Claude / opencode); deny JSON = BLOCK (Copilot)
#
# Sync order (Rule R7 extension for epic branch hierarchies):
#   1. Rebase epic/* on origin/master
#   2. Rebase feature/* on epic/*
#   3. Then push
#
# Run /orfi-kit-sync-branch to perform these steps automatically.

# The PreToolUse payload arrives as JSON on stdin; the Bash command lives at
# .tool_input.command. This previously read a TOOL_INPUT_command env var, which
# the harness never sets — so COMMAND was always empty, the git-push case below
# never matched, and this hook silently blocked nothing for its entire life.
#
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback (see README, "Hooks must not require anything the installer doesn't
# guarantee"). Never let a missing tool be the reason enforcement stops.
PAYLOAD="$(cat 2>/dev/null || true)"

# Platform contract. Same logic everywhere; only the output encoding differs.
# Unset = Claude's historical behavior, byte-for-byte.
HOOK_PLATFORM="${ORFI_HOOK_PLATFORM:-claude}"

# Copilot's PreToolUse payload carries the working directory at .cwd. Claude sets
# CLAUDE_PROJECT_DIR; opencode inherits $PWD. Prefer the payload's own answer.
PAYLOAD_CWD=""
if [ "$HOOK_PLATFORM" = "copilot" ]; then
  if command -v jq >/dev/null 2>&1; then
    PAYLOAD_CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // empty' 2>/dev/null || true)"
  else
    PAYLOAD_CWD="$(printf '%s' "$PAYLOAD" | tr -d '\n' \
      | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  fi
fi

if [ -n "$PAYLOAD" ]; then
  if command -v jq >/dev/null 2>&1; then
    COMMAND="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  else
    # Pull the "command" field out of the nested tool_input object. Keeps escaped
    # quotes intact (\" inside the value) by matching either an escape pair or a
    # non-quote character, then unescapes what git actually needs to see.
    COMMAND="$(printf '%s' "$PAYLOAD" \
      | tr -d '\n' \
      | sed -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*{[^{}]*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
      | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
    # Fall back to a flat "command" key if the nesting order differs.
    if [ -z "$COMMAND" ]; then
      COMMAND="$(printf '%s' "$PAYLOAD" \
        | tr -d '\n' \
        | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
        | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
    fi
  fi
else
  COMMAND=""
fi

# A payload we cannot parse must not read as "no push". Say so on stderr and let
# the tool call proceed — refusing to parse is not grounds to block a push, but
# staying quiet about it is how a broken guardrail passes for a working one.
if [ -n "$PAYLOAD" ] && [ -z "$COMMAND" ]; then
  case "$PAYLOAD" in
    *'"command"'*)
      echo "orfi-kit-enforce-sync: could not extract .tool_input.command from the PreToolUse payload; sync check skipped for this call." >&2
      ;;
  esac
fi

# Only intercept git push commands
case "$COMMAND" in
  *"git push"*) ;;
  *) exit 0 ;;
esac

# Resolve the worktree root
WORKTREE="${CLAUDE_PROJECT_DIR:-${PAYLOAD_CWD:-$PWD}}"

# Determine the current branch of this worktree
CURRENT_BRANCH=$(git -C "$WORKTREE" branch --show-current 2>/dev/null)

# Enforce on any epic-derived working branch (feature/, fix/, feat/, chore/,
# bugfix/, hotfix/, …) per orfi-kit-git-conventions. Never enforce on master or
# epic/* — those are not epic-derived working branches. Also skip when the
# branch is empty (detached HEAD).
case "$CURRENT_BRANCH" in
  ""|master|epic/*) exit 0 ;;
  *) ;;
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
    | grep "origin/epic/" \
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
  REASON="Working branch '$CURRENT_BRANCH' is out of sync with '$EPIC_BRANCH'.

The epic branch has been updated (rebased on master) and your working branch
does not include those changes.

Run /orfi-kit-sync-branch to fix this:
  1. Rebase $EPIC_BRANCH on origin/master
  2. Rebase $CURRENT_BRANCH on $EPIC_BRANCH
  3. Then push with --force-with-lease

Sync hierarchy: origin/master → $EPIC_BRANCH → $CURRENT_BRANCH"

  if [ "$HOOK_PLATFORM" = "copilot" ]; then
    # Copilot PreToolUse doesn't read an exit code for the decision; it reads a
    # deny decision JSON on stdout. Deliver the same reasoning on that channel.
    if command -v jq >/dev/null 2>&1; then
      printf '%s' "$REASON" | jq -Rs '{permissionDecision:"deny",permissionDecisionReason:.}'
    else
      ESCAPED="$(printf '%s' "$REASON" \
        | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' \
        | awk '{ printf "%s\\n", $0 }')"
      printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$ESCAPED"
    fi
    exit 0
  fi

  printf 'BLOCKED: %s\n' "$REASON"
  exit 1
fi

echo "Sync check passed: '$CURRENT_BRANCH' is up to date with '$EPIC_BRANCH'."
exit 0
