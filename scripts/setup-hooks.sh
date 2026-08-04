#!/usr/bin/env bash
#
# setup-hooks.sh — Linux/bash twin of setup-hooks.ps1.
#
# Wires this clone's git hooks to the repo's .githooks directory by running
# `git config core.hooksPath .githooks`, so .githooks/pre-commit fires on every
# commit. Behavioural twin of setup-hooks.ps1 — keep the two in sync.
#
# Also sets this clone's commit identity (see COMMIT_NAME/COMMIT_EMAIL below).
# This is a personal repo, and a machine whose GLOBAL git config carries a work
# identity would otherwise stamp it on every commit here. Both author AND
# committer must be covered: the committer is taken from config independently and
# is the one that leaks unnoticed, since only the author is usually displayed.
#
# One-time per clone. Git does not share hook config across clones or worktrees,
# so each needs this once. .git/config is not a tracked file — it cannot be
# committed — which is exactly why this belongs in a script that ships.
#
# The hook it wires runs the doc-presence checkers on staged files: *.cs via
# check-xml-docs, and headers (.h/.hpp/.hh/.hxx) via check-doxygen-docs.
#
# Usage:
#   bash scripts/setup-hooks.sh            # wire the hook up + set commit identity
#   bash scripts/setup-hooks.sh --unset    # revert to .git/hooks (disable)
#
# --unset reverts the hook path only. It deliberately leaves the identity alone:
# unsetting it would silently restore a work identity on a personal repo, which is
# the failure this guards against. Remove it by hand if you ever need to.

set -uo pipefail

# This clone's commit identity. Edit these two if you fork the kit.
COMMIT_NAME="Orfi"
COMMIT_EMAIL="waelorfi@aucegypt.edu"

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; RESET=''
fi

if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  printf '%serror: not inside a git repository.%s\n' "$RED" "$RESET" >&2
  exit 1
fi

if [ "${1:-}" = "--unset" ]; then
  git config --unset core.hooksPath 2>/dev/null || true
  printf '%sUnset core.hooksPath — git hooks revert to .git/hooks (hook disabled).%s\n' "$YELLOW" "$RESET"
  exit 0
fi

HOOKS_DIR="$REPO_ROOT/.githooks"
if [ ! -d "$HOOKS_DIR" ]; then
  printf '%serror: %s not found. Run this from a repo that ships .githooks/.%s\n' "$RED" "$HOOKS_DIR" "$RESET" >&2
  exit 1
fi

git config core.hooksPath .githooks
printf '%sSet core.hooksPath = .githooks%s\n' "$GREEN" "$RESET"

# Repo-local identity, overriding whatever the global config says. Reported rather
# than applied silently: a changed commit identity is something you should see.
git config user.name  "$COMMIT_NAME"
git config user.email "$COMMIT_EMAIL"
printf '%sSet commit identity = %s <%s>%s\n' "$GREEN" "$COMMIT_NAME" "$COMMIT_EMAIL" "$RESET"

# Verify it resolves, and say so if a global value still wins. `git var` reports
# the identity git would actually use, which is the only check that matters here.
ACTUAL_AUTHOR="$(git var GIT_AUTHOR_IDENT 2>/dev/null | sed 's/ [0-9]* [+-][0-9]*$//')"
ACTUAL_COMMITTER="$(git var GIT_COMMITTER_IDENT 2>/dev/null | sed 's/ [0-9]* [+-][0-9]*$//')"
EXPECTED="$COMMIT_NAME <$COMMIT_EMAIL>"
if [ "$ACTUAL_AUTHOR" = "$EXPECTED" ] && [ "$ACTUAL_COMMITTER" = "$EXPECTED" ]; then
  printf '%sVerified: author and committer both resolve to %s%s\n' "$GREEN" "$EXPECTED" "$RESET"
else
  printf '%swarning: identity did not take as expected.%s\n' "$YELLOW" "$RESET"
  printf '  author:    %s\n' "$ACTUAL_AUTHOR"
  printf '  committer: %s\n' "$ACTUAL_COMMITTER"
  printf '  expected:  %s\n' "$EXPECTED"
  printf '  Check for GIT_AUTHOR_* / GIT_COMMITTER_* env vars, which outrank config.\n'
fi

# Set the bit on disk AND in the index — git tracks the mode, so a clone made on
# another machine needs it recorded, not just applied locally.
if [ -f "$HOOKS_DIR/pre-commit" ]; then
  chmod +x "$HOOKS_DIR/pre-commit" 2>/dev/null || true
  git update-index --chmod=+x .githooks/pre-commit 2>/dev/null || true
  printf '%sMarked .githooks/pre-commit executable.%s\n' "$GREEN" "$RESET"
else
  printf '%swarning: .githooks/pre-commit is missing — nothing will run on commit.%s\n' "$YELLOW" "$RESET"
fi

echo
echo "Done. The pre-commit hook now runs on every commit in this clone."
echo "It checks staged .cs files for /// XML docs and staged headers for Doxygen blocks."
echo "Bypass in exceptional cases with: git commit --no-verify"
