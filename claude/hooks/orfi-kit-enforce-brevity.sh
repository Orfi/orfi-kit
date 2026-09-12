#!/bin/bash
# ENFORCEMENT HOOK: Block over-long assistant replies (concise-communication guardrail)
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : Stop — fires when the assistant finishes a reply
# Exit non-zero (2) = BLOCK: feed the reply back with an instruction to shorten
#
# Platform: exports ORFI_HOOK_PLATFORM=claude|opencode|copilot|codex. Claude reads the
#           block from stderr + exit 2. Copilot Stop takes a block decision JSON
#           on stdout (no exit-code contract there). opencode has no Stop event,
#           so this hook is not wired on that platform and never fakes it. Codex
#           has a Stop event but its transcript format is not a stable interface
#           for hooks, so it is also deliberately not wired on Codex and never
#           fakes it.
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

# Platform contract. Same logic everywhere; only the output encoding differs.
# Unset = Claude's historical behavior, byte-for-byte.
HOOK_PLATFORM="${ORFI_HOOK_PLATFORM:-claude}"

# The Stop hook receives a JSON payload on stdin with the transcript path.
PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

# Prevent infinite loops: if this Stop hook already fired once for this turn,
# Claude sets stop_hook_active. Do not re-block.
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback. Bailing out when jq is absent silently disabled this hook entirely.
if command -v jq >/dev/null 2>&1; then
  ACTIVE="$(printf '%s' "$PAYLOAD" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || true)"
else
  ACTIVE="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"stop_hook_active"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p')"
  [ -z "$ACTIVE" ] && ACTIVE=false
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" \
    | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | sed 's/\\\\/\\/g')"
fi

# Prevent an infinite block loop.
[ "$ACTIVE" = "true" ] && exit 0

[ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ] && exit 0

# Honesty guard for Copilot transcripts. Claude writes JSONL records carrying a
# "type" field; the Copilot transcript schema is not guaranteed to match. If we
# cannot recognise the shape, say we did not enforce rather than fake a pass.
if [ "$HOOK_PLATFORM" = "copilot" ] && ! grep -q '"type":"assistant"' "$TRANSCRIPT" 2>/dev/null; then
  echo "orfi-kit-enforce-brevity: transcript '$TRANSCRIPT' is not Claude-shaped; brevity NOT enforced on this session. Refusing to fake a pass." >&2
  exit 0
fi

# --- Extract the last assistant text turn and the last user prompt -----------
# Transcript is JSONL, one message object per line. Walk from the end.
if command -v jq >/dev/null 2>&1; then
  LAST_ASSISTANT_LINES="$(
    jq -rs '
      map(select(.type == "assistant"))
      | last
      | (.message.content // [])
      | map(select(.type == "text") | .text)
      | join("\n")
    ' "$TRANSCRIPT" 2>/dev/null || true
  )"
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
else
  # jq-free fallback. Take the last assistant/user JSONL record and pull out the
  # "text":"..." spans, converting the escaped newlines back to real ones so the
  # line count reflects the rendered reply.
  # The final assistant record is often a tool_use with no text at all, so take the
  # last record that actually CONTAINS a text span rather than simply the last one.
  LAST_ASSISTANT_LINES="$(
    grep '"type":"assistant"' "$TRANSCRIPT" 2>/dev/null \
      | grep '"text":"' | tail -n 1 \
      | grep -o '"text":"\(\\.\|[^"\\]\)*"' \
      | sed -e 's/^"text":"//' -e 's/"$//' -e 's/\\n/\n/g' || true
  )"
  LAST_USER_PROMPT="$(
    grep '"type":"user"' "$TRANSCRIPT" 2>/dev/null \
      | grep '"text":"' | tail -n 1 \
      | grep -o '"text":"\(\\.\|[^"\\]\)*"' \
      | sed -e 's/^"text":"//' -e 's/"$//' -e 's/\\n/\n/g' || true
  )"
fi

[ -z "$LAST_ASSISTANT_LINES" ] && exit 0

# --- Escape hatch: user explicitly asked for depth --------------------------
case "$(printf '%s' "$LAST_USER_PROMPT" | tr '[:upper:]' '[:lower:]')" in
  *"in full"*|*"in detail"*|*detailed*|*"explain in depth"*|*"in depth"*|\
  *"walk me through"*|*"step by step"*|*"long version"*|*"be thorough"*|*"full detail"*|\
  *elaborate*|*"full version"*|*"more detail"*|*"show more"*|*"more info"*|\
  *"expand on"*|*"tell me more"*|*"the whole"*|*"everything"*|*"full report"*|\
  *"comprehensive"*|*"deep dive"*|*"unabridged"*|*"no limit"*|*"as long as"*)
    exit 0 ;;
esac

# --- Count lines in the assistant reply --------------------------------------
LINE_COUNT="$(printf '%s\n' "$LAST_ASSISTANT_LINES" | wc -l | tr -d '[:space:]')"

if [ "$LINE_COUNT" -le "$MAX_LINES" ]; then
  exit 0
fi

# BLOCK: over the limit. Claude feeds stderr back on exit 2; Copilot Stop takes
# a block decision JSON on stdout. Same reasoning, per-platform channel.
REASON="your reply is ${LINE_COUNT} lines; the limit is ${MAX_LINES} (~one page).

Rewrite it far shorter:
  - Lead with the answer or the single decision that's actually needed.
  - Cut restated context, hedging, and options you won't pursue.
  - One idea per line. No walls.

If the user genuinely needs depth, they'll ask ('in detail', 'in full') and the
limit lifts. Default is brief."

if [ "$HOOK_PLATFORM" = "copilot" ]; then
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$REASON" | jq -Rs '{decision:"block",reason:.}'
  else
    ESCAPED="$(printf '%s' "$REASON" \
      | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' \
      | awk '{ printf "%s\\n", $0 }')"
    printf '{"decision":"block","reason":"%s"}\n' "$ESCAPED"
  fi
  exit 0
fi

echo "BLOCKED: $REASON" >&2
exit 2
