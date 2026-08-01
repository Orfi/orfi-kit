#!/bin/bash
# ADVISORY HOOK: Load the repo's own C++ conventions before a source/header is written
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PreToolUse on Write|Edit|MultiEdit (filtered here to C/C++ extensions)
# Exit 0 always = ADVISORY: never blocks a write, only injects the rules
#
# Rationale: conventions were consulted only at review time, so code got written
# blind to the repo's own config and fixed afterwards — or shipped and caught by
# CI. This moves the rules to write time: emit what actually governs this file
# before it is edited, so the first draft is already compliant.
#
# Authority (see the code-review skills' CONFIG.md — read, never edited here):
# THE REPO UNDER REVIEW ALWAYS WINS. This hook reports only what the target repo
# encodes. Most C++ repos ship NO .clang-format and NO .clang-tidy; per CONFIG.md
# that is the common case and normal, not an error. When nothing is encoded the
# honest move is to follow the prevailing pattern of the file being edited — so
# this hook says exactly that and imports no external style guide.
#
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback (README, "Hooks must not require anything the installer doesn't
# guarantee"). A missing tool must never be why this hook stops checking.

MAX_RULE_LINES="${ORFI_CONVENTIONS_MAX_LINES:-120}"

PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

# The PreToolUse payload carries the target path at .tool_input.file_path.
# Matchers in settings.json match TOOL NAMES, not globs, so the extension filter
# has to happen here rather than in the matcher.
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  FILE_PATH="$(printf '%s' "$PAYLOAD" | tr -d '\n' \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
    | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g')"
fi

[ -z "$FILE_PATH" ] && exit 0

# .inl is included: it is a header in practice and the C++ review skill's own
# file filter covers it.
case "$FILE_PATH" in
  *.cpp|*.hpp|*.h|*.cc|*.cxx|*.inl) ;;
  *) exit 0 ;;
esac

# Vendored and generated code follows its upstream's conventions, not yours.
case "$FILE_PATH" in
  */third_party/*|*/external/*|*/vendor/*|*\\third_party\\*|*\\external\\*|*\\vendor\\*) exit 0 ;;
  */ui_*.h|*/moc_*.cpp|*/qrc_*.cpp|ui_*.h|moc_*.cpp|qrc_*.cpp) exit 0 ;;
esac

# --- Walk up for the nearest .clang-format / .clang-tidy / compile db --------
# Both clang config files resolve nearest-file-wins up the directory tree, so the
# closest one to this file is the one that governs it.
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

FMT="$(find_up .clang-format || true)"
TIDY="$(find_up .clang-tidy || true)"

# compile_commands.json may sit in the tree or in a build dir beside it.
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

BASE="${FILE_PATH##*/}"

if [ -z "$FMT" ] && [ -z "$TIDY" ]; then
  # The repo encodes nothing — the COMMON case in C++. Fall back to the kit's own
  # baseline, which ships in the code-review skill's CONFIG.md. Read it from disk
  # rather than duplicating it here: one source of truth, so the baseline cannot
  # drift out of step with the review skill that documents it.
  #
  # Precedence is unchanged and non-negotiable: the repo under review ALWAYS wins.
  # This branch only runs when there is nothing to win against.
  BASELINE=""
  for CAND in \
    "$HOME/.claude/skills/orfi-kit-cpp-code-review/CONFIG.md" \
    "$HOME/.copilot/skills/orfi-kit-cpp-code-review/CONFIG.md" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills/orfi-kit-cpp-code-review/CONFIG.md"
  do
    [ -f "$CAND" ] && { BASELINE="$CAND"; break; }
  done

  echo "[ORFI C++ CONVENTIONS — $BASE]"
  echo "This repo encodes NOTHING: no .clang-format, no .clang-tidy. That is the common"
  echo "case in C++ and not an error."
  echo

  if [ -z "$BASELINE" ]; then
    echo "The orfi-kit baseline (CONFIG.md) is not installed either, so no rule is"
    echo "enforceable here. Follow the prevailing pattern of THIS file and its immediate"
    echo "siblings and say that is what you did. Do not import a general C++ style guide."
    exit 0
  fi

  echo "ENFORCING the orfi-kit baseline as the contract for this repo. These are the"
  echo "kit's house-style defaults, from $BASELINE."
  echo "Deviation is a violation and should be reported as one, including in"
  echo "pre-existing code you touch. Write this file to the rules below."
  echo

  # CONFIG.md ships two yaml blocks: .clang-format first, then .clang-tidy.
  echo "  --- baseline .clang-format"
  awk '/^```yaml/{n++; if(n==1){f=1;next}} f&&/^```/{exit} f' "$BASELINE" \
    | grep -vE '^[[:space:]]*(#|$)' | head -n "$MAX_RULE_LINES" | sed 's/^/  /'
  echo
  echo "  --- baseline .clang-tidy (naming keys paired with their values)"
  awk '/^```yaml/{n++; if(n==2){f=1;next}} f&&/^```/{exit} f' "$BASELINE" \
    | awk '
      /readability-identifier-naming\./ {
        k=$0; sub(/.*readability-identifier-naming\./,"",k); sub(/[[:space:]]*$/,"",k)
        if (k ~ /:[[:space:]]*[^[:space:]]/) { print "    " k; key=""; next }
        key=k; next
      }
      key != "" && /value[[:space:]]*:/ {
        v=$0; sub(/.*value[[:space:]]*:[[:space:]]*/,"",v); sub(/[[:space:]]*$/,"",v)
        print "    " key " = " v; key=""
      }
      /^[[:space:]]*WarningsAsErrors:/ { print "    " $0 }
    ' | head -n "$MAX_RULE_LINES"
  echo
  echo "NOTE: with no config in the repo, clang-format and clang-tidy have nothing to"
  echo "read — the baseline is enforced by you applying it, not by a tool. To make it"
  echo "enforceable by the build and CI, adopt the baseline as the repo's own"
  echo ".clang-format / .clang-tidy. This hook is read-only and will never write them."
  echo
  echo "No tool enforces FILENAMES in any case. Apply the baseline's filename rule to"
  echo "NEW files only, and never propose bulk renames: a rename breaks every #include"
  echo "of the old name."
  exit 0
fi

echo "[ORFI C++ CONVENTIONS — the repo's own rules for $BASE]"
echo "These come from this repo's config and outrank general C++ habit. Write the"
echo "first draft compliant; do not defer formatting and naming to review or CI."
echo

if [ -n "$FMT" ]; then
  echo "--- $FMT (formatting, include order)"
  # Emit the governing keys, not the whole file: top-level scalars plus the
  # include-category blocks that decide include ordering.
  grep -vE '^[[:space:]]*(#|$)' "$FMT" 2>/dev/null | head -n "$MAX_RULE_LINES"
  echo
fi

if [ -n "$TIDY" ]; then
  echo "--- $TIDY (naming, static analysis)"
  # readability-identifier-naming.* is where naming actually lives — one key per
  # symbol kind. Emit those in full; they are the rules a name is judged against.
  # A key on its own is useless — "ClassCase" without "CamelCase" tells you
  # nothing to write. .clang-tidy splits each option across a `- key:` line and
  # the `value:` line after it, so pair them back up into one readable line.
  NAMING="$(awk '
    /readability-identifier-naming\./ {
      k = $0
      sub(/.*readability-identifier-naming\./, "", k)
      sub(/[[:space:]]*$/, "", k)
      # Same-line form: "key: value" or "readability-...X: Y"
      if (k ~ /:[[:space:]]*[^[:space:]]/) { print "    " k; key = ""; next }
      key = k; next
    }
    key != "" && /value[[:space:]]*:/ {
      v = $0; sub(/.*value[[:space:]]*:[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v)
      print "    " key " = " v; key = ""
    }
  ' "$TIDY" 2>/dev/null)"
  if [ -n "$NAMING" ]; then
    echo "  Identifier naming (readability-identifier-naming.*):"
    printf '%s\n' "$NAMING" | head -n "$MAX_RULE_LINES"
  else
    echo "  No readability-identifier-naming.* keys — this .clang-tidy does not encode naming."
  fi

  # Stop at the next top-level key so WarningsAsErrors/CheckOptions don't bleed in.
  CHECKS="$(awk '
    /^[[:space:]]*Checks:/ { inb = 1; print; next }
    inb && /^[[:alpha:]][[:alnum:]_]*:/ { exit }
    inb { print }
  ' "$TIDY" 2>/dev/null | head -n 40)"
  [ -n "$CHECKS" ] && { echo; echo "  Enabled checks:"; printf '%s\n' "$CHECKS" | sed 's/^[[:space:]]*/    /'; }

  WAE="$(grep -E '^[[:space:]]*WarningsAsErrors:' "$TIDY" 2>/dev/null | head -1)"
  if [ -n "$WAE" ]; then
    echo
    echo "  $(printf '%s' "$WAE" | sed 's/^[[:space:]]*//')"
    echo "  => Those checks FAIL the build. Not nits."
  fi

  # Ownership policy is encoded, not assumed — report it if the repo set it.
  if grep -qE 'cppcoreguidelines-owning-memory' "$TIDY" 2>/dev/null; then
    echo
    echo "  cppcoreguidelines-owning-memory is ENABLED: this repo has encoded a"
    echo "  smart-pointer ownership policy. Raw owning pointers are a real violation."
  fi
  echo

  # Per CONFIG.md: clang-tidy is largely INERT without a compilation database.
  if [ -z "$CDB" ]; then
    echo "  !! No compile_commands.json found. clang-tidy cannot resolve includes"
    echo "     without it and is largely INERT, so the naming rules above will NOT be"
    echo "     mechanically enforced on this edit — you must apply them by reading."
    echo "     (CMake emits one with CMAKE_EXPORT_COMPILE_COMMANDS=ON; qmake needs a"
    echo "     wrapper such as bear. Generating it is a build action, not this hook's job.)"
  else
    echo "  Compilation database: $CDB — clang-tidy can run and will enforce the above."
  fi
  echo
fi

echo "No tool enforces FILENAMES — clang-tidy covers identifiers only. Treat any"
echo "filename convention as advisory, and never propose bulk renames: a rename"
echo "breaks every #include that refers to the old name."
echo
echo "Advisory only — this hook never blocks a write. But these are the rules the"
echo "build and the review will measure this file against, so apply them now."
exit 0
