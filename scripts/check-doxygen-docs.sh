#!/usr/bin/env bash
#
# check-doxygen-docs.sh — Linux/bash port of check-doxygen-docs.ps1.
#
# Detects public/protected/static C++ declarations in HEADER files missing a
# Doxygen comment. Scans .h/.hpp/.hh/.hxx files for exposed declarations
# (functions, methods, classes, structs, enums, templates) not preceded by a
# Doxygen block — either a /** ... */ block or one or more /// lines. Reports
# violations and exits 1 if any are found, 0 if all exposed declarations are
# documented. Behavioural twin of check-doxygen-docs.ps1 — keep the two in sync.
#
# Scope: HEADER FILES ONLY (.h .hpp .hh .hxx). .cpp/.cc are skipped — the API
# surface lives in headers (linkage-correct). Within a class/struct, only
# public: and protected: sections are checked; private: is never checked.
# Namespace-scope declarations default to documentable. Either /** */ or ///
# is accepted — style is NOT enforced (the skill owns style consistency).
# Exclusions: *.generated.* files; obj/ bin/ build/ path segments.
#
# HONEST LIMITATION: C++ access-section tracking in regex is harder than C#'s
# per-member access modifiers. This script is good-enough for CI — it catches
# undocumented public/protected declarations in normal headers — but it does
# NOT perfectly parse pathological cases: deeply-nested classes, macro-obscured
# declarations, or heavy template metaprogramming. The always-active
# /orfi-kit-doxygen-docs skill is the real enforcer; this script is the CI
# backstop.
#
# Usage:
#   scripts/check-doxygen-docs.sh --changed                 # .h* changed since HEAD + staged
#   scripts/check-doxygen-docs.sh --staged                  # .h* staged in git (diff --cached)
#   scripts/check-doxygen-docs.sh --files a.hpp b.h         # explicit file list
#   scripts/check-doxygen-docs.sh a.hpp b.h                 # bare args == --files

set -uo pipefail

# Header extensions only. .cpp/.cc are never scanned.
HEADER_EXT_REGEX='\.(h|hpp|hh|hxx)$'

# Matches exposed declarations: functions/methods, class/struct/enum/union, and
# templates. Pragmatic, good-enough for CI (see HONEST LIMITATION above).
TYPE_PATTERN='^[[:space:]]*(template[[:space:]]*<|class[[:space:]]|struct[[:space:]]|enum([[:space:]]|$)|union[[:space:]])'
FUNC_PATTERN='[A-Za-z_][A-Za-z0-9_:<>~&*[:space:]]*\('

EXCLUDE_FILE_GLOBS=('*.generated.*')
EXCLUDE_PATH_SEGMENTS=('obj' 'bin' 'build')

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
    -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
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
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -E "$HEADER_EXT_REGEX" || true)
elif [ "$MODE" = "changed" ]; then
  mapfile -t FILES < <( { git diff --name-only HEAD 2>/dev/null;
                          git diff --cached --name-only --diff-filter=ACM 2>/dev/null; } \
                        | grep -E "$HEADER_EXT_REGEX" | sort -u || true)
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  printf '%sℹ️  No header files to check.%s\n' "$CYAN" "$RESET"
  exit 0
fi

should_exclude() {
  local path="$1" base normalized seg glob
  base="$(basename "$path")"
  # Header-only: skip anything that is not a .h/.hpp/.hh/.hxx (incl. .cpp/.cc).
  [[ "$base" =~ $HEADER_EXT_REGEX ]] || return 0
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

  mapfile -t LINES < "$full"
  total=${#LINES[@]}

  # --- access-section + class-depth tracking (good-enough for CI) ------------
  # depth 0 == namespace scope (documentable). Inside a class/struct body the
  # current section starts at the type's default: private for class, public for
  # struct. public:/protected:/private: labels flip it.
  depth=0
  # stacks indexed by depth; element 0 is the namespace-scope sentinel.
  section_stack=("ns")           # current section per nesting level
  default_stack=("ns")           # default section per nesting level
  # Non-type ("plain") open braces — function bodies, initializers, namespaces,
  # enum bodies — that are NOT class/struct type levels. Tracked separately so a
  # multi-line inline method body does not pop the enclosing class's section
  # depth one line early (which previously corrupted access-section tracking).
  plain_braces=0

  for (( i=0; i<total; i++ )); do
    line="${LINES[$i]}"

    # ltrim/rtrim for analysis
    lt="${line#"${line%%[![:space:]]*}"}"          # ltrim
    lt="${lt%"${lt##*[![:space:]]}"}"              # rtrim

    # --- track access-section labels (public:/protected:/private:) ----------
    if [[ "$lt" =~ ^(public|protected|private)[[:space:]]*: ]]; then
      section_stack[$depth]="${BASH_REMATCH[1]}"
      continue
    fi

    # --- detect entering a class/struct body --------------------------------
    is_type=0
    [[ "$lt" =~ $TYPE_PATTERN ]] && is_type=1

    # A bare template<...> preamble line is NOT itself flagged — the type or
    # function on the following line is the real declaration, and the doc-walk
    # skips back over template lines. (Avoids double-counting.)
    is_template_preamble=0
    [[ "$lt" == template* ]] && is_template_preamble=1

    # --- decide if this line is an exposed declaration we must check --------
    cur_section="${section_stack[$depth]}"
    documentable=0
    if [ "$cur_section" = "ns" ] || [ "$cur_section" = "public" ] || [ "$cur_section" = "protected" ]; then
      documentable=1
    fi

    candidate=0
    if [ "$is_template_preamble" -eq 1 ]; then
      candidate=0
    elif [ "$is_type" -eq 1 ]; then
      candidate=1
    elif [[ "$lt" =~ $FUNC_PATTERN ]]; then
      candidate=1
    fi

    # Skip obvious non-declarations.
    case "$lt" in
      "" ) candidate=0 ;;                                  # blank
      \}* | \{* ) candidate=0 ;;                           # brace-only / continuation
      //* | /\** | \** ) candidate=0 ;;                    # comment lines
      \#* ) candidate=0 ;;                                 # preprocessor
      using\ * | typedef\ * | friend\ * ) candidate=0 ;;   # pragmatic skips
      return\ * | else* | for\ * | while\ * | if\ * | switch\ * | case\ * ) candidate=0 ;;
    esac
    # A control-flow / call line that just happens to match FUNC_PATTERN but is
    # not a type and not at a checkable place: only flag function candidates
    # that look like declarations (end with ; or ) or { , and contain no '=').
    if [ "$candidate" -eq 1 ] && [ "$is_type" -eq 0 ]; then
      case "$lt" in
        *=* ) candidate=0 ;;                              # assignment / init, not a decl
      esac
      case "$lt" in
        *\;* | *\)* ) ;;                                  # plausible decl/def
        * ) candidate=0 ;;
      esac
    fi

    if [ "$candidate" -eq 1 ] && [ "$documentable" -eq 1 ]; then
      # Walk backward through attributes/blank/preproc lines looking for a
      # Doxygen block (/// lines OR a closing */ of a /** ... */ block).
      has_doc=0
      j=$(( i - 1 ))
      while [ "$j" -ge 0 ]; do
        prev="${LINES[$j]}"
        prev="${prev#"${prev%%[![:space:]]*}"}"          # ltrim
        prev="${prev%"${prev##*[![:space:]]}"}"          # rtrim
        # /// style
        if [[ "$prev" == /\/\/* ]]; then has_doc=1; break; fi
        # closing */ of a multi-line /** ... */ block, or a one-line /** ... */
        if [[ "$prev" == *\*/ ]] || [[ "$prev" == /\*\** ]]; then has_doc=1; break; fi
        # attributes, blank lines, preprocessor lines, and template<...> preamble
        # lines: keep walking back (the doc block sits above them).
        if [[ "$prev" == \[\[* ]] || [ -z "$prev" ] || [[ "$prev" == \#* ]] || [[ "$prev" == template* ]]; then j=$(( j - 1 )); continue; fi
        break
      done

      if [ "$has_doc" -eq 0 ]; then
        member="$lt"
        member="${member:0:120}"
        violations+=("${file}:$(( i + 1 ))"$'\t'"${member}")
        violation_count=$(( violation_count + 1 ))
      fi
    fi

    # --- update nesting depth based on braces on this line ------------------
    # Count { and } to descend/ascend class bodies. When entering a class/struct
    # on this line, push the new default section. All other (non-type) braces —
    # function bodies, initializers, namespaces, enum bodies — accumulate into
    # plain_braces so their closers unwind THEM first, before any type level is
    # popped. This stops a multi-line inline method body from prematurely popping
    # the enclosing class section.
    opens="${line//[^\{]/}"; closes="${line//[^\}]/}"
    n_open=${#opens}; n_close=${#closes}

    if [ "$is_type" -eq 1 ] && [ "$n_open" -gt 0 ]; then
      # entering a type body: default section depends on class vs struct
      newdefault="private"
      case "$lt" in
        struct\ * | struct* | union\ * | union* ) newdefault="public" ;;
        class\ * | class* ) newdefault="private" ;;
      esac
      depth=$(( depth + 1 ))
      section_stack[$depth]="$newdefault"
      default_stack[$depth]="$newdefault"
      n_open=$(( n_open - 1 ))
    fi

    # Remaining opens on this line are plain (non-type) opens.
    plain_braces=$(( plain_braces + n_open ))

    # Each close first unwinds a plain brace; only when no plain braces remain
    # does a close pop a type-section level.
    c=$n_close
    while [ "$c" -gt 0 ]; do
      if [ "$plain_braces" -gt 0 ]; then
        plain_braces=$(( plain_braces - 1 ))
      elif [ "$depth" -gt 0 ]; then
        unset 'section_stack[$depth]'
        unset 'default_stack[$depth]'
        depth=$(( depth - 1 ))
      fi
      c=$(( c - 1 ))
    done
  done
done

if [ "$violation_count" -gt 0 ]; then
  printf '\n%s❌ Missing Doxygen comments — %d violation(s):%s\n\n' "$RED" "$violation_count" "$RESET"
  for v in "${violations[@]}"; do
    loc="${v%%$'\t'*}"; member="${v#*$'\t'}"
    printf '  %s%s%s\n' "$YELLOW" "$loc" "$RESET"
    printf '  %s→ %s%s\n\n' "$GRAY" "$member" "$RESET"
  done
  printf '%sFix: add a /** @brief ... */ (or /// ...) Doxygen block above each flagged declaration.%s\n' "$CYAN" "$RESET"
  printf '%sSee: /orfi-kit-doxygen-docs skill for the full tag reference.%s\n' "$CYAN" "$RESET"
  exit 1
fi

printf '%s✅ All public/protected declarations are documented.%s\n' "$GREEN" "$RESET"
exit 0
