#!/bin/bash
# ENFORCEMENT HOOK: Block over-long assistant replies (concise-communication guardrail)
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : Stop — fires when the assistant finishes a reply
# Exit non-zero (2) = BLOCK: feed the reply back with an instruction to shorten
#
# Rationale: the assistant repeatedly shipped page-length replies for small tasks.
# Advisory "be concise" instructions did not bind. This hook mechanically measures
# the last assistant turn and blocks it when it exceeds MAX_LINES, forcing a rewrite.
#
# Threshold: 25 lines (~one printed page). Override with ORFI_BREVITY_MAX_LINES.
# Escape hatch: if the user's last prompt asks for depth (e.g. "in full",
# "detailed", "explain in depth", "long", "walk me through"), the limit is lifted
# for that turn — brevity is the default, not a gag.

set -euo pipefail

MAX_LINES="${ORFI_BREVITY_MAX_LINES:-25}"

# The Stop hook receives a JSON payload on stdin with the transcript path.
PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

# Prevent infinite loops: if this Stop hook already fired once for this turn,
# Claude sets stop_hook_active. Do not re-block.
if command -v jq >/dev/null 2>&1; then
  ACTIVE="$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
  [ "$ACTIVE" = "true" ] && exit 0
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
else
  # No jq — cannot parse safely; do not block.
  exit 0
fi

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# --- Extract the last assistant text turn and the last user prompt -----------
# Transcript is JSONL, one message object per line. Walk from the end.
LAST_ASSISTANT_LINES="$(
  jq -rs '
    map(select(.type == "assistant"))
    | last
    | (.message.content // [])
    | map(select(.type == "text") | .text)
    | join("\n")
  ' "$TRANSCRIPT" 2>/dev/null || true
)"
[ -z "$LAST_ASSISTANT_LINES" ] && exit 0

LAST_USER_PROMPT="$(
  jq -rs '
    map(select(.type == "user"))
    | last
    | (.message.content // [])
    | (if type == "array"
       then map(select(.type? == "text") | .text) | join("\n")
       else tostring end)
  ' "$TRANSCRIPT" 2>/dev/null || true
)"

# --- Escape hatch: user explicitly asked for depth --------------------------
case "$(printf '%s' "$LAST_USER_PROMPT" | tr '[:upper:]' '[:lower:]')" in
  *"in full"*|*"in detail"*|*detailed*|*"explain in depth"*|*"in depth"*|\
  *"walk me through"*|*"step by step"*|*"long version"*|*"be thorough"*|*"full detail"*)
    exit 0 ;;
esac

# --- Count lines in the assistant reply --------------------------------------
LINE_COUNT="$(printf '%s\n' "$LAST_ASSISTANT_LINES" | wc -l | tr -d '[:space:]')"

if [ "$LINE_COUNT" -le "$MAX_LINES" ]; then
  exit 0
fi

# BLOCK: over the limit. stderr is fed back to the assistant on exit 2.
echo "BLOCKED: your reply is ${LINE_COUNT} lines; the limit is ${MAX_LINES} (~one page).

Rewrite it far shorter:
  - Lead with the answer or the single decision that's actually needed.
  - Cut restated context, hedging, and options you won't pursue.
  - One idea per line. No walls.

If the user genuinely needs depth, they'll ask ('in detail', 'in full') and the
limit lifts. Default is brief." >&2
exit 2
