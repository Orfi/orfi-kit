#!/bin/bash
# ENFORCEMENT HOOK: Block a skill's final report when its mandated steps have no transcript record
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : Stop — fires when the assistant finishes a reply
# Exit non-zero (2) = BLOCK: feed the gaps back and make the assistant run them
#
# Rationale: the code-review skills mandate companion skills (/security-review,
# /orfi-kit-xml-docs) and a tool lane (dotnet format/build/test). The prose is
# explicit, compelling, and did not bind: a review was reported three times in one
# session with both companions never invoked, then reported a fourth time claiming
# one of them had been. Across every session in this project the transcript holds
# no `"skill":"security-review"` record at all. Advisory text cannot fix this
# because the thing being asked for is self-restraint at the exact moment the
# model believes it already knows the answer.
#
# So this hook does what the brevity hook did for reply length: measure, don't ask.
#
# THE LEDGER. Claude Code writes the session transcript as JSONL, and every tool
# call lands in it as a harness-authored `tool_use` record:
#   {"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill",
#    "input":{"skill":"security-review"}}]}}
# The model authors the `input`, but it cannot author the RECORD. It can write "I
# invoked /security-review" into prose; it cannot make that line exist. Prose is a
# claim, the record is evidence, and this hook only reads evidence.
#
# ATTEMPT, NOT SUCCESS. A required step is satisfied by the record of the call, not
# by its exit code. An unavailable skill, an uninstalled `dotnet`, a solution that
# will not restore — each leaves a record and each satisfies the requirement. That
# preserves the honest "skipped (unavailable)" verdict the skills allow, while
# removing the option to decide a step was unnecessary without ever trying it.
#
# WHEN IT FIRES. Only when a contract is open AND the reply is report-shaped. The
# contract opens at the last Skill call naming a contract-bearing skill; only
# records after that point count. Mid-review turns are never touched, so this
# gates the deliverable rather than interrupting the work.
#
# jq is NOT installed on every machine this runs on, so parse with sed/grep as the
# fallback (README, "Hooks must not require anything the installer doesn't
# guarantee"). A missing tool must never be why enforcement stops.
#
# Escape hatch: ORFI_SKILL_CONTRACT_OFF=1 disables it. There is deliberately no
# in-conversation phrase that lifts this gate — a gate the model can talk its way
# past is the failure mode being fixed, not a feature. Turning it off is the
# user's call, made outside the conversation.

set -uo pipefail

[ "${ORFI_SKILL_CONTRACT_OFF:-0}" = "1" ] && exit 0

# Where contracts live. A skill's contract sits beside its SKILL.md, so an
# installed skill and its rules travel together and cannot drift apart.
SKILL_DIRS="${ORFI_SKILL_DIRS:-$HOME/.claude/skills}"

PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

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

# Prevent an infinite block loop. One block per turn; the assistant gets the
# message and acts on it, and a second pass must not re-block the same reply.
[ "$ACTIVE" = "true" ] && exit 0
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# --- Find the open contract --------------------------------------------------
# Walk the transcript once, recording the LAST line number at which each
# contract-bearing skill was invoked. Last, not first: a session may run the
# review twice, and only the current pass is being judged.
CONTRACT_FILE=""
CONTRACT_SKILL=""
CONTRACT_LINE=0

for dir in $SKILL_DIRS; do
  [ -d "$dir" ] || continue
  for cf in "$dir"/*/CONTRACT.conf; do
    [ -f "$cf" ] || continue
    skill="$(basename "$(dirname "$cf")")"
    # A skill is invoked in TWO distinct ways, and both must open the contract:
    #
    #   1. The Skill tool      -> {"name":"Skill","input":{"skill":"x"}}
    #   2. A slash command     -> {"type":"user", ... "<command-name>/x</command-name>"}
    #
    # This matters more than it looks. In the real session that prompted this hook,
    # the review was started as a slash command at line 76 and the Skill tool only
    # appeared at line 407 — the remedial pass, after the user caught the skip.
    # Matching form 1 alone would have opened the contract at 407, skipped the
    # entire original review, and stayed silent through exactly the failure it is
    # meant to catch. Both compact ("skill":"x") and spaced ("skill": "x") JSON
    # encodings are accepted, since the writer is free to choose either.
    line_tool="$(grep -n "\"skill\"[[:space:]]*:[[:space:]]*\"$skill\"" "$TRANSCRIPT" 2>/dev/null \
      | tail -n 1 | cut -d: -f1)"
    line_slash="$(grep -n "<command-name>/$skill</command-name>" "$TRANSCRIPT" 2>/dev/null \
      | tail -n 1 | cut -d: -f1)"
    # Take whichever came LAST: that is the pass currently being judged.
    line="$line_tool"
    if [ -n "$line_slash" ]; then
      if [ -z "$line" ] || [ "$line_slash" -gt "$line" ] 2>/dev/null; then line="$line_slash"; fi
    fi
    [ -z "$line" ] && continue
    if [ "$line" -gt "$CONTRACT_LINE" ] 2>/dev/null; then
      CONTRACT_LINE="$line"; CONTRACT_FILE="$cf"; CONTRACT_SKILL="$skill"
    fi
  done
done

# No contract-bearing skill was ever invoked this session. Nothing to enforce.
[ -z "$CONTRACT_FILE" ] && exit 0

# Everything the contract judges happened AFTER the skill was invoked. Slicing
# here also means a prior turn's satisfied requirement cannot be reused to excuse
# a later pass that skipped it.
WINDOW="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/orfi-contract-$$")"
trap 'rm -f "$WINDOW"' EXIT
tail -n "+$CONTRACT_LINE" "$TRANSCRIPT" > "$WINDOW" 2>/dev/null || exit 0

# --- Extract the assistant's final reply -------------------------------------
# Needed twice: to decide whether this reply is a report at all, and to detect a
# claim that contradicts the record.
if command -v jq >/dev/null 2>&1; then
  REPLY="$(jq -rs '
      map(select(.type == "assistant"))
      | last
      | (.message.content // [])
      | map(select(.type == "text") | .text)
      | join("\n")
    ' "$WINDOW" 2>/dev/null || true)"
else
  # The final assistant record is often a tool_use carrying no text, so take the
  # last record that actually contains a text span rather than simply the last.
  REPLY="$(
    grep '"type":"assistant"' "$WINDOW" 2>/dev/null \
      | grep '"text":"' | tail -n 1 \
      | grep -o '"text":"\(\\.\|[^"\\]\)*"' \
      | sed -e 's/^"text":"//' -e 's/"$//' -e 's/\\n/\n/g' || true
  )"
fi

[ -z "$REPLY" ] && exit 0

# --- Is this reply report-shaped? --------------------------------------------
# A report is recognised by the section headings the skill's own Report section
# mandates. Requiring several of them (report-min) rather than one keeps a passing
# mention of the word "Verdict" mid-conversation from tripping the gate.
MARKERS=0
MIN_MARKERS=3
while IFS= read -r raw; do
  case "$raw" in \#*|"") continue ;; esac
  kind="${raw%%::*}"; rest="${raw#*::}"
  case "$kind" in
    report-marker)
      # Match the marker as a report heading: bold, ATX heading, or list label.
      if printf '%s' "$REPLY" | grep -qiE "(^|[*#|_[:space:]])$rest\b" 2>/dev/null; then
        MARKERS=$((MARKERS + 1))
      fi ;;
    report-min) MIN_MARKERS="$rest" ;;
  esac
done < "$CONTRACT_FILE"

# Not a report — the review is still in progress. Never interrupt work.
[ "$MARKERS" -lt "$MIN_MARKERS" ] && exit 0

# --- Check each requirement against the record -------------------------------
MISSING=""
FABRICATED=""
VIOLATED=""

while IFS= read -r raw; do
  case "$raw" in \#*|"") continue ;; esac

  kind="${raw%%::*}"; rest="${raw#*::}"
  [ "$kind" = "report-marker" ] && continue
  [ "$kind" = "report-min" ] && continue

  what="${rest%%::*}"; rest="${rest#*::}"
  pattern="${rest%%::*}"; rest="${rest#*::}"
  label="${rest%%::*}"
  note=""
  case "$rest" in *::*) note="${rest#*::}" ;; esac

  case "$what" in
    skill)
      # An exact skill id, matched inside a Skill tool_use input.
      if grep -qE "\"skill\"[[:space:]]*:[[:space:]]*\"$pattern\"" "$WINDOW" 2>/dev/null; then
        found=yes
      else
        found=no
      fi ;;
    bash)
      # The command as recorded in the Bash tool_use input. Matching the raw JSON
      # line is intentional: it needs no unescaping and cannot be satisfied by the
      # command merely being QUOTED in the report prose, because prose lands in a
      # text span, not in a "command" field.
      if grep -E '"command"[[:space:]]*:' "$WINDOW" 2>/dev/null | grep -qE "$pattern" 2>/dev/null; then
        found=yes
      else
        found=no
      fi ;;
    *) continue ;;
  esac

  if [ "$kind" = "forbid" ]; then
    # A forbid row is a trap that was actually stepped in.
    [ "$found" = "yes" ] && VIOLATED="$VIOLATED
  - $label
      why: $note"
    continue
  fi

  [ "$found" = "yes" ] && continue

  # Required and absent. If the report also ASSERTS it ran, that is the more
  # serious finding — a skipped step is an omission, a skipped step reported as
  # done is a false statement — so name it as such.
  if [ -n "$note" ] && printf '%s' "$REPLY" | grep -qiE "$note" 2>/dev/null; then
    FABRICATED="$FABRICATED
  - $label — the report refers to this, but no tool_use record exists for it"
  else
    MISSING="$MISSING
  - $label"
  fi
done < "$CONTRACT_FILE"

[ -z "$MISSING" ] && [ -z "$FABRICATED" ] && [ -z "$VIOLATED" ] && exit 0

# --- BLOCK: stderr on exit 2 is fed back to the assistant --------------------
{
  echo "BLOCKED: this report does not match the session record."
  echo
  echo "Contract: $CONTRACT_SKILL (CONTRACT.conf, enforced from the transcript)."
  echo "Your reply is report-shaped, so $CONTRACT_SKILL's mandated steps must all"
  echo "have a tool_use record after the skill was invoked. These do not:"

  [ -n "$FABRICATED" ] && {
    echo
    echo "CLAIMED BUT NOT RECORDED — the report says or implies these ran:"
    echo "$FABRICATED"
  }
  [ -n "$MISSING" ] && {
    echo
    echo "NOT RUN:"
    echo "$MISSING"
  }
  [ -n "$VIOLATED" ] && {
    echo
    echo "RUN THE WRONG WAY — these produce a pass that inspected nothing:"
    echo "$VIOLATED"
  }

  cat <<'EOF'

What to do now:
  1. Actually invoke each step above. Do not summarise, infer, or substitute your
     own analysis for a companion skill — that substitution is exactly what this
     gate exists to catch.
  2. A step that CANNOT run still has to be attempted. The attempt leaves a record
     and satisfies the requirement; its failure is then a real, reportable fact.
     "skipped (unavailable)" is honest only after trying.
  3. Then rewrite the report from what the tools actually returned.

Do not reply with a corrected report before running them — the record is checked,
not the wording, so an edited report with no new records will be blocked again.
EOF
} >&2
exit 2
