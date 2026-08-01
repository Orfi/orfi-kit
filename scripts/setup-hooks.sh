#!/usr/bin/env bash
#
# setup-hooks.sh — Linux/bash twin of setup-hooks.ps1.
#
# Wires this clone's git hooks to the repo's .githooks directory by running
# `git config core.hooksPath .githooks`, so .githooks/pre-commit fires on every
# commit. Behavioural twin of setup-hooks.ps1 — keep the two in sync.
#
# One-time per clone. Git does not share hook config across clones or worktrees,
# so each needs this once.
#
# The hook it wires runs the doc-presence checkers on staged files: *.cs via
# check-xml-docs, and headers (.h/.hpp/.hh/.hxx) via check-doxygen-docs.
#
# Usage:
#   bash scripts/setup-hooks.sh            # wire the hook up
#   bash scripts/setup-hooks.sh --unset    # revert to .git/hooks (disable)

set -uo pipefail

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
