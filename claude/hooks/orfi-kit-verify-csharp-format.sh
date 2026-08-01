#!/bin/bash
# ADVISORY HOOK: Verify a just-written .cs file against the repo's own format rules
# Scope   : Global (~/.claude/hooks/) — applies to all projects
# Trigger : PostToolUse on Write|Edit|MultiEdit (filtered here to *.cs)
# Exit 0 always = ADVISORY: reports violations, never blocks the edit
#
# Claude-Code-only. The Copilot SDK exposes only onSessionStart and
# onUserPromptSubmitted — no per-edit and no post-response event — so there is no
# Copilot equivalent of this verifier and we do not pretend otherwise. The same
# asymmetry is already documented for the brevity guardrail in extension.mjs.
#
# Advisory, not blocking, deliberately: a PostToolUse hook fires per edit, so a
# multi-file change is verified while it is still half-written, and any
# pre-existing debt in the same project reports against an author who never
# touched it. Blocking on that would make every edit hostage to unrelated
# violations. Set ORFI_CSHARP_FORMAT_BLOCKING=1 to exit 2 instead (opt-in).
#
# jq is NOT installed on every machine this runs on, so parse with sed as the
# fallback (README, "Hooks must not require anything the installer doesn't
# guarantee"). A missing tool must never be why this hook stops checking.

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
  *.cs) ;;
  *) exit 0 ;;
esac

case "$FILE_PATH" in
  *.g.cs|*.designer.cs|*.generated.cs|*/Migrations/*|*\\Migrations\\*) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

# --- Bail gracefully when the toolchain isn't there --------------------------
if ! command -v dotnet >/dev/null 2>&1; then
  echo "orfi-kit-verify-csharp-format: dotnet not on PATH — format not verified for ${FILE_PATH##*/}." >&2
  exit 0
fi

# --- Find the containing project --------------------------------------------
# dotnet format needs an MSBuild anchor; walk up for the nearest .csproj.
DIR="$(dirname "$FILE_PATH")"
PROJECT=""
while [ -n "$DIR" ] && [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
  CANDIDATE="$(ls "$DIR"/*.csproj 2>/dev/null | head -1)"
  if [ -n "$CANDIDATE" ]; then PROJECT="$CANDIDATE"; break; fi
  PARENT="$(dirname "$DIR")"
  [ "$PARENT" = "$DIR" ] && break
  DIR="$PARENT"
done

if [ -z "$PROJECT" ]; then
  echo "orfi-kit-verify-csharp-format: no .csproj above ${FILE_PATH##*/} — format not verified." >&2
  exit 0
fi

# --- Run the verifier -------------------------------------------------------
# CRITICAL: capture the exit code from the BARE invocation. Piping it
# (`dotnet format ... | tail`) makes $? the status of the LAST command in the
# pipeline — tail always succeeds, so a real violation silently reads as clean.
# Redirect to a temp file, assign $? on the very next line, THEN filter for
# display. --include scopes the analysis to this one file so a large project
# doesn't get re-verified on every keystroke.
#
# --include must be given a path RELATIVE to the project. An absolute path is
# accepted and then silently matches nothing — dotnet format analyses zero files
# and exits 0, so a violating file reads as clean. Verified on this machine: the
# same violating file gives $?=2 relative and $?=0 with either absolute form
# (/c/... or C:\...). Derive the relative path and run from the project dir.
PROJECT_DIR="$(dirname "$PROJECT")"
REL_PATH="${FILE_PATH#"$PROJECT_DIR"/}"

TMP_OUT="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/orfi-csfmt.$$")"
trap 'rm -f "$TMP_OUT"' EXIT

# If the file somehow isn't under the project dir, the prefix strip is a no-op and
# we'd be back to passing an absolute path. Fall back to the whole project rather
# than run a check that cannot fail.
if [ "$REL_PATH" = "$FILE_PATH" ]; then
  ( cd "$PROJECT_DIR" && dotnet format "$(basename "$PROJECT")" --verify-no-changes --verbosity quiet ) >"$TMP_OUT" 2>&1
  FORMAT_EXIT=$?
else
  ( cd "$PROJECT_DIR" && dotnet format "$(basename "$PROJECT")" --verify-no-changes --include "$REL_PATH" --verbosity quiet ) >"$TMP_OUT" 2>&1
  FORMAT_EXIT=$?
fi

if [ "$FORMAT_EXIT" -eq 0 ]; then
  # Clean. Stay silent: a hook that congratulates every edit is noise.
  exit 0
fi

echo "[ORFI C# FORMAT] dotnet format reports violations in ${FILE_PATH##*/} (exit $FORMAT_EXIT)."
echo "Project: $PROJECT"
echo
sed -n '1,40p' "$TMP_OUT"
echo
echo "These are this repo's own .editorconfig / analyzer rules, not general C# habit."
echo "Fix them now — under TreatWarningsAsErrors they are a build break, and leaving"
echo "them turns a write-time fix into a review or CI failure."

# Opt-in blocking. Default is advisory: see the header for why.
if [ "${ORFI_CSHARP_FORMAT_BLOCKING:-0}" = "1" ]; then
  echo "ORFI_CSHARP_FORMAT_BLOCKING=1 — treating this as a block." >&2
  exit 2
fi
exit 0
