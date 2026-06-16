#!/usr/bin/env bash
#
# check-xml-docs.sh — Linux/bash port of check-xml-docs.ps1.
#
# Detects public/protected/static C# members missing /// XML doc comments.
# Scans .cs files for public or protected member declarations not preceded by a
# /// XML doc comment block. Reports violations and exits 1 if any are found, 0
# if all members are documented. Behavioural twin of check-xml-docs.ps1 — keep
# the two in sync.
#
# Scope: public and protected members only. private members are never checked.
# Exclusions: auto-generated files, Migrations/, obj/, bin/.
#
# Usage:
#   scripts/check-xml-docs.sh --changed                 # .cs changed since HEAD + staged
#   scripts/check-xml-docs.sh --staged                  # .cs staged in git (diff --cached)
#   scripts/check-xml-docs.sh --files a.cs b.cs         # explicit file list
#   scripts/check-xml-docs.sh a.cs b.cs                 # bare args == --files

set -uo pipefail

# Matches public/protected member declarations (classes, interfaces, methods, properties, enums, etc.)
MEMBER_PATTERN='^[[:space:]]*(public|protected)([[:space:]]+(static|virtual|override|abstract|async|sealed|readonly|new|extern|partial))*[[:space:]]+[^[:space:]]'

EXCLUDE_FILE_GLOBS=('*.g.cs' '*.designer.cs' '*.generated.cs')
EXCLUDE_PATH_SEGMENTS=('Migrations' 'obj' 'bin')

# --- colors (only when stdout is a tty) --------------------------------------
if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; CYAN=$'\033[36m'; GRAY=$'\033[90m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; GRAY=''; RESET=''
fi

# --- arg parsing -------------------------------------------------------------
MODE="files"
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --staged)  MODE="staged"; shift ;;
    --changed) MODE="changed"; shift ;;
    --files)   MODE="files"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *)         FILES+=("$1"); shift ;;
  esac
done

repo_root() {
  local root
  if root=$(git rev-parse --show-toplevel 2>/dev/null); then
    printf '%s' "$root"
  else
    pwd
  fi
}

# --- resolve files to scan ---------------------------------------------------
if [ "$MODE" = "staged" ]; then
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E '\.cs$' || true)
elif [ "$MODE" = "changed" ]; then
  mapfile -t FILES < <( { git diff --name-only HEAD 2>/dev/null;
                          git diff --cached --name-only --diff-filter=ACM 2>/dev/null; } \
                        | grep -E '\.cs$' | sort -u || true)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  printf '%sℹ️  No .cs files to check.%s\n' "$CYAN" "$RESET"
  exit 0
fi

should_exclude() {
  local path="$1" base normalized seg glob
  base="$(basename "$path")"
  for glob in "${EXCLUDE_FILE_GLOBS[@]}"; do
    # shellcheck disable=SC2053
    [[ "$base" == $glob ]] && return 0
  done
  normalized="${path//\\//}"
  for seg in "${EXCLUDE_PATH_SEGMENTS[@]}"; do
    [[ "$normalized" == *"/$seg/"* ]] && return 0
  done
  return 1
}

REPO_ROOT="$(repo_root)"
violation_count=0
violations=()

for file in "${FILES[@]}"; do
  [ -z "$file" ] && continue
  if [[ "$file" = /* ]]; then full="$file"; else full="$REPO_ROOT/$file"; fi
  [ -f "$full" ] || continue
  should_exclude "$full" && continue

  # Read file into an array of lines (1-based index tracked via lineno).
  lineno=0
  mapfile -t LINES < "$full"
  total=${#LINES[@]}
  for (( i=0; i<total; i++ )); do
    line="${LINES[$i]}"

    [[ "$line" =~ $MEMBER_PATTERN ]] || continue

    trimmed_end="${line%"${line##*[![:space:]]}"}"   # rtrim
    # Skip plain field declarations (end with ';' and no '{')
    if [[ "$trimmed_end" =~ \;[[:space:]]*$ ]] && [[ "$line" != *'{'* ]]; then
      continue
    fi

    # Walk backward through attributes/blank/preproc lines looking for ///
    has_doc=0
    j=$(( i - 1 ))
    while [ "$j" -ge 0 ]; do
      prev="${LINES[$j]}"
      prev="${prev#"${prev%%[![:space:]]*}"}"        # ltrim
      prev="${prev%"${prev##*[![:space:]]}"}"        # rtrim
      if [[ "$prev" == /\/\/* ]]; then has_doc=1; break; fi
      if [[ "$prev" == \[* ]] || [ -z "$prev" ] || [[ "$prev" == \#* ]]; then j=$(( j - 1 )); continue; fi
      break
    done

    if [ "$has_doc" -eq 0 ]; then
      member="${line#"${line%%[![:space:]]*}"}"      # ltrim for display
      member="${member%"${member##*[![:space:]]}"}"  # rtrim
      member="${member:0:120}"
      violations+=("${file}:$(( i + 1 ))"$'\t'"${member}")
      violation_count=$(( violation_count + 1 ))
    fi
  done
done

if [ "$violation_count" -gt 0 ]; then
  printf '\n%s❌ Missing /// XML doc comments — %d violation(s):%s\n\n' "$RED" "$violation_count" "$RESET"
  for v in "${violations[@]}"; do
    loc="${v%%$'\t'*}"; member="${v#*$'\t'}"
    printf '  %s%s%s\n' "$YELLOW" "$loc" "$RESET"
    printf '  %s→ %s%s\n\n' "$GRAY" "$member" "$RESET"
  done
  printf '%sFix: add a /// <summary>...</summary> block above each flagged member.%s\n' "$CYAN" "$RESET"
  printf '%sSee: /orfi-kit-xml-docs skill for the full tag reference.%s\n' "$CYAN" "$RESET"
  exit 1
fi

printf '%s✅ All public/protected members are documented.%s\n' "$GREEN" "$RESET"
exit 0
