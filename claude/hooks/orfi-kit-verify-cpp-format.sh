#!/bin/bash
# ADVISORY HOOK: Verify a just-written C/C++ file against the repo's own rules
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PostToolUse on Write|Edit|MultiEdit (filtered here to C/C++ extensions)
# Exit 0 always = ADVISORY: reports violations, never blocks the edit
#
# Platform: exports ORFI_HOOK_PLATFORM=claude|opencode|copilot. The verification
#           is identical everywhere; only the delivery channel differs (see the
#           emit section at the bottom). Claude reads hookSpecificOutput.
#           additionalContext; Copilot PostToolUse reads a top-level
#           additionalContext (no block semantics there); opencode merges
#           output.output into the tool result so the model still sees findings.
#
# Advisory, not blocking, deliberately: a PostToolUse hook fires per edit, so a
# multi-file change is verified while it is still half-written, and any
# pre-existing debt in the same file reports against an author who never touched
# it. That is especially true in C++, where most repos have no config at all and
# formatting drift is the norm. Set ORFI_CPP_FORMAT_BLOCKING=1 to exit 2 (opt-in).
#
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback (README, "Hooks must not require anything the installer doesn't
# guarantee"). A missing tool must never be why this hook stops checking.

# Platform contract. Same logic everywhere; only the output encoding differs.
# Unset = Claude's historical behavior, byte-for-byte.
HOOK_PLATFORM="${ORFI_HOOK_PLATFORM:-claude}"

PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  FILE_PATH="$(printf '%s' "$PAYLOAD" | tr -d '\n' \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
    | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g')"
fi

[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.cpp|*.hpp|*.h|*.cc|*.cxx|*.inl) ;;
  *) exit 0 ;;
esac

case "$FILE_PATH" in
  */third_party/*|*/external/*|*/vendor/*|*\\third_party\\*|*\\external\\*|*\\vendor\\*) exit 0 ;;
  */ui_*.h|*/moc_*.cpp|*/qrc_*.cpp|ui_*.h|moc_*.cpp|qrc_*.cpp) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

BASE="${FILE_PATH##*/}"

find_up() {
  local name="$1" dir; dir="$(dirname "$FILE_PATH")"
  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    [ -f "$dir/$name" ] && { printf '%s\n' "$dir/$name"; return 0; }
    local parent; parent="$(dirname "$dir")"
    [ "$parent" = "$dir" ] && break
    dir="$parent"
  done
  return 1
}

FMT_CFG="$(find_up .clang-format || true)"
TIDY_CFG="$(find_up .clang-tidy || true)"

REPORTED=0
FINDINGS=""

# Advisory must not mean invisible. On exit 0 plain stdout only reaches the
# transcript, so findings printed there are effectively swallowed — the "wired but
# enforces nothing" failure the README warns about. Collect findings here and
# deliver them at the end via hookSpecificOutput.additionalContext, which the
# harness defines as non-error feedback delivered TO THE MODEL so it can act on it.
add_finding() { FINDINGS="${FINDINGS}$1
"; }

# --- Formatting: clang-format ------------------------------------------------
# Only meaningful when the repo actually ships a .clang-format. Without one,
# clang-format would fall back to a built-in style the repo never agreed to, and
# reporting against that is inventing a rule. Per CONFIG.md, don't.
if [ -n "$FMT_CFG" ]; then
  if command -v clang-format >/dev/null 2>&1; then
    # CRITICAL: capture the exit code from the BARE invocation. Piping it
    # (`clang-format ... | tail`) makes $? the status of the LAST pipeline
    # command — tail always succeeds, so a real violation reads as clean.
    TMP_FMT="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/orfi-cppfmt.$$")"
    clang-format --dry-run --Werror --style=file "$FILE_PATH" >"$TMP_FMT" 2>&1
    FMT_EXIT=$?

    if [ "$FMT_EXIT" -ne 0 ]; then
      REPORTED=1
      add_finding "[ORFI C++ FORMAT] clang-format reports violations in $BASE (exit $FMT_EXIT).
Config: $FMT_CFG

$(sed -n '1,30p' "$TMP_FMT")
"
    fi
    rm -f "$TMP_FMT"
  else
    echo "orfi-kit-verify-cpp-format: clang-format not on PATH — formatting not verified for $BASE (config exists at $FMT_CFG)." >&2
  fi
fi

# --- Naming / analysis: clang-tidy ------------------------------------------
# Per CONFIG.md, clang-tidy is largely INERT without a compilation database: it
# cannot resolve includes, and its output is unreliable. Run it ONLY when one
# exists; otherwise say why naming could not be checked rather than emitting
# noise or implying the file passed.
if [ -n "$TIDY_CFG" ]; then
  CDB="$(find_up compile_commands.json || true)"
  if [ -z "$CDB" ]; then
    DIR="$(dirname "$FILE_PATH")"
    while [ -n "$DIR" ] && [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
      for B in build out cmake-build-debug cmake-build-release; do
        [ -f "$DIR/$B/compile_commands.json" ] && { CDB="$DIR/$B/compile_commands.json"; break; }
      done
      [ -n "$CDB" ] && break
      PARENT="$(dirname "$DIR")"; [ "$PARENT" = "$DIR" ] && break; DIR="$PARENT"
    done
  fi

  if ! command -v clang-tidy >/dev/null 2>&1; then
    echo "orfi-kit-verify-cpp-format: clang-tidy not on PATH — naming not verified for $BASE (config exists at $TIDY_CFG)." >&2
  elif [ -z "$CDB" ]; then
    echo "orfi-kit-verify-cpp-format: no compile_commands.json — clang-tidy is inert without a compilation database, so NAMING WAS NOT CHECKED for $BASE. This is unverified, not clean. (CMake: CMAKE_EXPORT_COMPILE_COMMANDS=ON; qmake: use bear.)" >&2
  else
    # Same unpiped-exit-code rule as above.
    TMP_TIDY="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/orfi-cpptidy.$$")"
    clang-tidy -p "$(dirname "$CDB")" --quiet "$FILE_PATH" >"$TMP_TIDY" 2>&1
    TIDY_EXIT=$?

    if [ "$TIDY_EXIT" -ne 0 ] || grep -qE 'warning:|error:' "$TMP_TIDY" 2>/dev/null; then
      REPORTED=1
      add_finding "[ORFI C++ NAMING/ANALYSIS] clang-tidy findings in $BASE (exit $TIDY_EXIT).
Config: $TIDY_CFG   Compilation database: $CDB

$(grep -E 'warning:|error:' "$TMP_TIDY" 2>/dev/null | sed -n '1,30p')
"
    fi
    rm -f "$TMP_TIDY"
  fi
fi

if [ "$REPORTED" -eq 0 ]; then
  # Clean, or nothing was enforceable. Stay silent — any "could not verify" note
  # has already gone to stderr above.
  exit 0
fi

MSG="${FINDINGS}These are this repo's own .clang-format / .clang-tidy rules, not general C++
habit. FIX THEM NOW, in this file, before moving on — leaving them turns a
write-time fix into a review or CI failure, and under WarningsAsErrors a naming
hit is a build break. Do not report this edit as done while they stand."

# Human-visible copy on stderr, plus the actionable copy to the model. Both,
# deliberately: the user should see that the check ran and what it found.
printf '%s\n' "$MSG" >&2

# JSON-encode for delivery. jq when present; otherwise escape by hand - a missing
# jq must not be why the finding goes undelivered. Order matters: backslashes
# first, then quotes, then strip CR, then fold newlines. Per-platform channel:
#   claude  -> hookSpecificOutput.additionalContext (model sees and must act)
#   copilot -> top-level additionalContext
#   opencode-> output.output, which the plugin merges into the tool result
emit_json() {
  case "$HOOK_PLATFORM" in
    copilot)
      printf '%s' "$MSG" | jq -Rs '{additionalContext:.}' 2>/dev/null \
        || { ESCAPED="$(printf '%s' "$MSG" \
             | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' \
             | awk '{ printf "%s\\n", $0 }')"; \
             printf '{"additionalContext":"%s"}\n' "$ESCAPED"; } ;;
    opencode)
      printf '%s' "$MSG" | jq -Rs '{output:{output:.}}' 2>/dev/null \
        || { ESCAPED="$(printf '%s' "$MSG" \
             | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' \
             | awk '{ printf "%s\\n", $0 }')"; \
             printf '{"output":{"output":"%s"}}\n' "$ESCAPED"; } ;;
    *)
      printf '%s' "$MSG" | jq -Rs '{
        hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: . }
      }' 2>/dev/null \
        || { ESCAPED="$(printf '%s' "$MSG" \
             | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' \
             | awk '{ printf "%s\\n", $0 }')"; \
             printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$ESCAPED"; } ;;
  esac
}
emit_json

# Opt-in blocking is Claude-only. Copilot PostToolUse has no block semantics and
# opencode merges rather than gates, so those platforms are always advisory.
if [ "$HOOK_PLATFORM" = "claude" ] && [ "${ORFI_CPP_FORMAT_BLOCKING:-0}" = "1" ]; then
  echo "ORFI_CPP_FORMAT_BLOCKING=1 — treating this as a block." >&2
  exit 2
fi
exit 0
