#!/bin/bash
# ADVISORY HOOK: Load the repo's own C# conventions before a .cs file is written
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PreToolUse on Write|Edit|MultiEdit (filtered here to *.cs)
# Exit 0 always = ADVISORY: never blocks a write, only injects the rules
#
# Rationale: conventions were consulted only at review time, so code got written
# blind to the repo's own config and fixed afterwards — or shipped and caught by
# CI. This moves the rules to write time: emit what actually governs this file
# before it is edited, so the first draft is already compliant.
#
# Authority (see the code-review skills' CONFIG.md — read, never edited here):
# THE REPO UNDER REVIEW ALWAYS WINS. This hook reports only what the target repo
# encodes. It ships no baseline of its own and invents no rule; where the repo
# encodes nothing, it says so and stays silent rather than importing a default.
#
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback (README, "Hooks must not require anything the installer doesn't
# guarantee"). A missing tool must never be why this hook stops checking.

MAX_RULE_LINES="${ORFI_CONVENTIONS_MAX_LINES:-120}"

PAYLOAD="$(cat 2>/dev/null || true)"
[ -z "$PAYLOAD" ] && exit 0

# The PreToolUse payload carries the target path at .tool_input.file_path.
# Matchers in settings.json match TOOL NAMES, not globs, so the *.cs filter has
# to happen here rather than in the matcher.
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
else
  FILE_PATH="$(printf '%s' "$PAYLOAD" | tr -d '\n' \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\(\\.\|[^"\\]\)*\)".*/\1/p' \
    | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g')"
fi

[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.cs) ;;
  *) exit 0 ;;
esac

# Generated and migration files are excluded from the doc/naming rules anyway.
case "$FILE_PATH" in
  *.g.cs|*.designer.cs|*.generated.cs|*/Migrations/*|*\\Migrations\\*) exit 0 ;;
esac

# --- Walk up for the nearest .editorconfig, honouring root = true ------------
# .editorconfig cascades nearest-file-wins up the tree and stops at root = true.
# Collect nearest-first so the closest file's rules are the ones shown.
DIR="$(dirname "$FILE_PATH")"
CONFIGS=""
while [ -n "$DIR" ] && [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
  if [ -f "$DIR/.editorconfig" ]; then
    CONFIGS="$CONFIGS $DIR/.editorconfig"
    # root = true terminates the cascade.
    if grep -qiE '^[[:space:]]*root[[:space:]]*=[[:space:]]*true' "$DIR/.editorconfig" 2>/dev/null; then
      break
    fi
  fi
  PARENT="$(dirname "$DIR")"
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
done

# --- Find Directory.Build.props for the build-gate properties ---------------
DIR="$(dirname "$FILE_PATH")"
PROPS=""
while [ -n "$DIR" ] && [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
  if [ -f "$DIR/Directory.Build.props" ]; then PROPS="$DIR/Directory.Build.props"; break; fi
  PARENT="$(dirname "$DIR")"
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
done

if [ -z "$CONFIGS" ] && [ -z "$PROPS" ]; then
  # Nothing encoded. Per CONFIG.md this is a gap in the repo, not a rule to
  # invent — say so once and stop. Do NOT substitute general C# habit.
  echo "[ORFI C# CONVENTIONS] No .editorconfig or Directory.Build.props found above ${FILE_PATH##*/}."
  echo "Nothing in this repo encodes naming or formatting, so no rule is enforceable here."
  echo "Follow the prevailing pattern of the surrounding file and say that is what you did."
  exit 0
fi

echo "[ORFI C# CONVENTIONS — the repo's own rules for ${FILE_PATH##*/}]"
echo "These come from this repo's config and outrank general C# habit. Write the"
echo "first draft compliant; do not defer naming and formatting to review or CI."
echo

# --- Emit the [*.cs] / [*] sections of each .editorconfig, nearest first ----
for CFG in $CONFIGS; do
  echo "--- $CFG"

  # Section-scoped extraction: keep [*], [*.cs], [*.{...cs...}] blocks only.
  # Whole files are never emitted — only the sections that govern C#.
  SECTION="$(awk '
    /^[[:space:]]*\[/ {
      line = $0
      sub(/^[[:space:]]*\[/, "", line); sub(/\][[:space:]]*$/, "", line)
      keep = (line == "*" || line == "*.cs" || (line ~ /\{/ && line ~ /(^|[,{[:space:]])cs([,}]|$)/))
      next
    }
    keep && /^[[:space:]]*(#|;)/ { next }
    keep && NF { print }
  ' "$CFG" 2>/dev/null)"

  # Naming rules are three cooperating families. Split across the output they are
  # unreadable, so group each rule with the symbols and style it references.
  NAMING="$(printf '%s\n' "$SECTION" | grep -E '^[[:space:]]*dotnet_naming_' 2>/dev/null)"
  OTHER="$(printf '%s\n' "$SECTION" | grep -vE '^[[:space:]]*dotnet_naming_' 2>/dev/null | grep -E '=' )"

  if [ -n "$OTHER" ]; then
    printf '%s\n' "$OTHER" | head -n "$MAX_RULE_LINES"
  fi

  if [ -n "$NAMING" ]; then
    echo
    echo "  Naming rules as COMPLETE TRIPLETS (rule -> symbols -> style):"
    # For each rule.<name>.symbols / .style, pull the matching symbol and style keys.
    printf '%s\n' "$NAMING" | sed -n 's/^[[:space:]]*dotnet_naming_rule\.\([^.]*\)\..*/\1/p' | sort -u | while read -r RULE
    do
      [ -z "$RULE" ] && continue
      SEV="$(printf '%s\n' "$NAMING"  | sed -n "s/^[[:space:]]*dotnet_naming_rule\.$RULE\.severity[[:space:]]*=[[:space:]]*//p" | head -1)"
      SYMS="$(printf '%s\n' "$NAMING" | sed -n "s/^[[:space:]]*dotnet_naming_rule\.$RULE\.symbols[[:space:]]*=[[:space:]]*//p" | head -1)"
      STY="$(printf '%s\n' "$NAMING"  | sed -n "s/^[[:space:]]*dotnet_naming_rule\.$RULE\.style[[:space:]]*=[[:space:]]*//p" | head -1)"
      echo "  * rule '$RULE' (severity: ${SEV:-unset})"
      if [ -n "$SYMS" ]; then
        echo "      symbols '$SYMS':"
        printf '%s\n' "$NAMING" | grep -E "^[[:space:]]*dotnet_naming_symbols\.$SYMS\." | sed 's/^[[:space:]]*/        /'
      fi
      if [ -n "$STY" ]; then
        echo "      style '$STY':"
        printf '%s\n' "$NAMING" | grep -E "^[[:space:]]*dotnet_naming_style\.$STY\." | sed 's/^[[:space:]]*/        /'
      fi
    done
    echo
    echo "  READ applicable_kinds LITERALLY: 'field' COVERS const AND static readonly."
    echo "  A const IS a field, so a field rule (e.g. required_prefix = _) applies to it."
    echo "  Misreading this is a known cause of mass naming violations — a PascalCase"
    echo "  private const has passed review and broken the build under"
    echo "  TreatWarningsAsErrors."
  fi
  echo
done

# --- Build gate properties --------------------------------------------------
if [ -n "$PROPS" ]; then
  echo "--- $PROPS"
  for PROP in TreatWarningsAsErrors EnforceCodeStyleInBuild Nullable; do
    VAL="$(sed -n "s|.*<$PROP>\([^<]*\)</$PROP>.*|\1|p" "$PROPS" 2>/dev/null | head -1)"
    [ -n "$VAL" ] && echo "  $PROP = $VAL"
  done
  if grep -qiE '<TreatWarningsAsErrors>[[:space:]]*true' "$PROPS" 2>/dev/null; then
    echo "  => Warnings FAIL the build. A style or naming warning is a build break,"
    echo "     not a nit. Getting it right in this edit is cheaper than a CI failure."
  fi
  echo
fi

echo "Advisory only — this hook never blocks a write. But these are the rules the"
echo "build and the review will measure this file against, so apply them now."
exit 0
