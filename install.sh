#!/usr/bin/env bash
#
# orfi-kit installer.
#
# orfi-kit is skills/markdown plus one hook and one Copilot extension. This
# script is install-time plumbing only: it copies (or symlinks) skills,
# commands, the sync hook (+ settings.json wiring), and the Copilot extension
# into the right directories for Claude Code, OpenCode, and/or GitHub Copilot CLI.
#
# Usage:
#   ./install.sh                 interactive: asks which runtime(s) to install for
#   ./install.sh --link          symlink instead of copy (dev: repo edits go live)
#   ./install.sh --uninstall     remove an existing orfi-kit install
#   ./install.sh --help          show this help
#
# Claude Code + OpenCode share one skill source (claude/skills) and the
# command files (claude/commands). Copilot uses its OWN source (copilot/skills,
# 19 dirs) and its own home (~/.copilot/skills) — no command file (in Copilot a
# skill IS its slash command).
#
# Conflict rule (OpenCode reads BOTH ~/.claude/skills and ~/.config/opencode/skills):
# those skills get exactly ONE home per machine so the two never drift —
#   * Claude Code only        -> ~/.claude/skills/
#   * OpenCode only           -> ~/.config/opencode/skills/
#   * both runtimes installed -> ~/.claude/skills/ only (OpenCode reads it natively)

set -euo pipefail

# --- paths -------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/claude/skills"            # Claude Code + OpenCode share this source
COPILOT_SKILLS_SRC="$REPO_DIR/copilot/skills"   # Copilot has its own copy
CMDS_SRC="$REPO_DIR/claude/commands"
HOOK_SRC="$REPO_DIR/claude/hooks/orfi-kit-enforce-sync.sh"
BREVITY_SRC="$REPO_DIR/claude/hooks/orfi-kit-enforce-brevity.sh"
EXT_SRC="$REPO_DIR/copilot/extensions/orfi-kit-guardrails"

CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_CMDS="$HOME/.claude/commands"
CLAUDE_HOOKS="$HOME/.claude/hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
OPENCODE_SKILLS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
OPENCODE_CMDS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/commands"
COPILOT_SKILLS="$HOME/.copilot/skills"          # Copilot's own home — no command file
COPILOT_EXTS="$HOME/.copilot/extensions"        # verified from Copilot CLI bundle

HOOK_DEST="$CLAUDE_HOOKS/orfi-kit-enforce-sync.sh"
HOOK_CMD="bash \"\$HOME/.claude/hooks/orfi-kit-enforce-sync.sh\""

BREVITY_DEST="$CLAUDE_HOOKS/orfi-kit-enforce-brevity.sh"
BREVITY_CMD="bash \"\$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh\""

# The 5 Claude skill dirs (shared by Claude Code + OpenCode).
CLAUDE_SKILL_NAMES=(orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-scrum-poker orfi-kit-xml-docs orfi-kit-doxygen-docs)

# The 19 Copilot skill dirs.
COPILOT_SKILL_NAMES=(
  orfi-kit-cleanup-state orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails
  orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-init orfi-kit-load-state
  orfi-kit-persist-state orfi-kit-run-codegraph-phase
  orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase
  orfi-kit-scrum-poker orfi-kit-set-helper-files-root orfi-kit-standup
  orfi-kit-sync-branch orfi-kit-sync-master orfi-kit-xml-docs orfi-kit-doxygen-docs
)

# The 14 command files (Claude Code / OpenCode only). Per-capability docs live
# in docs/skills/ (repo docs, not runtime); the installer copies only these.
COMMAND_NAMES=(
  orfi-kit-cleanup-state orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails
  orfi-kit-init orfi-kit-load-state orfi-kit-persist-state orfi-kit-run-codegraph-phase
  orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase
  orfi-kit-set-helper-files-root orfi-kit-standup orfi-kit-sync-branch orfi-kit-sync-master
)

LINK=0
MODE="install"

# --- helpers -----------------------------------------------------------------

say()  { printf '%s\n' "$*"; }
err()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^#$//; s/^# //'
  exit 0
}

# place one item (dir or file) from src -> dest, copy or symlink per $LINK
place() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  if [ "$LINK" -eq 1 ]; then
    ln -s "$src" "$dest"
    say "  linked  $dest"
  else
    cp -R "$src" "$dest"
    say "  copied  $dest"
  fi
}

install_claude_skills_to() {
  local target_dir="$1"
  for s in "${CLAUDE_SKILL_NAMES[@]}"; do place "$SKILLS_SRC/$s" "$target_dir/$s"; done
}

remove_claude_skills_from() {
  local target_dir="$1"
  for s in "${CLAUDE_SKILL_NAMES[@]}"; do
    if [ -e "$target_dir/$s" ] || [ -L "$target_dir/$s" ]; then
      rm -rf "$target_dir/$s"; say "  removed $target_dir/$s"
    fi
  done
}

install_commands_to() {
  local target_dir="$1"
  mkdir -p "$target_dir"
  for c in "${COMMAND_NAMES[@]}"; do place "$CMDS_SRC/$c.md" "$target_dir/$c.md"; done
}

remove_commands_from() {
  local target_dir="$1"
  for c in "${COMMAND_NAMES[@]}"; do
    if [ -e "$target_dir/$c.md" ]; then
      rm -f "$target_dir/$c.md"; say "  removed $target_dir/$c.md"
    fi
  done
}

install_copilot_skills() {
  for s in "${COPILOT_SKILL_NAMES[@]}"; do place "$COPILOT_SKILLS_SRC/$s" "$COPILOT_SKILLS/$s"; done
}

remove_copilot_skills() {
  for s in "${COPILOT_SKILL_NAMES[@]}"; do
    if [ -e "$COPILOT_SKILLS/$s" ] || [ -L "$COPILOT_SKILLS/$s" ]; then
      rm -rf "$COPILOT_SKILLS/$s"; say "  removed $COPILOT_SKILLS/$s"
    fi
  done
}

have_claude_skills_in() { [ -e "$1/orfi-kit-guardrails/SKILL.md" ] || [ -L "$1/orfi-kit-guardrails" ]; }

# --- NEW (beyond trackbed): settings.json hook wiring ------------------------
# Merge a PreToolUse/Bash entry into ~/.claude/settings.json idempotently.
# Backs up to settings.json.bak first. Requires jq; falls back to manual
# instructions if jq is missing or the file is malformed.

wire_hook() {
  place "$HOOK_SRC" "$HOOK_DEST"
  chmod +x "$HOOK_DEST" 2>/dev/null || true

  if ! command -v jq >/dev/null 2>&1; then
    say ""
    say "  jq not found — cannot auto-wire settings.json. Add this manually to"
    say "  $CLAUDE_SETTINGS under .hooks.PreToolUse:"
    print_manual_hook_json
    return 0
  fi

  printf '  Wire the hook into %s automatically? [Y/n] ' "$CLAUDE_SETTINGS"
  read -r reply
  case "$reply" in
    [Nn]*) say "  Skipped. To wire manually, add to .hooks.PreToolUse:"; print_manual_hook_json; return 0 ;;
  esac

  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"

  if ! jq empty "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
    say "  $CLAUDE_SETTINGS is not valid JSON — not touching it. Add manually:"
    print_manual_hook_json
    return 0
  fi

  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"
  say "  backed up $CLAUDE_SETTINGS -> $CLAUDE_SETTINGS.bak"

  # Idempotent merge: only add a Bash PreToolUse entry running our hook if no
  # existing entry already runs it.
  local tmp
  tmp="$(mktemp)"
  jq --arg cmd "$HOOK_CMD" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    if any(.hooks.PreToolUse[]?; .matcher == "Bash" and any(.hooks[]?; .command == $cmd))
    then .
    else .hooks.PreToolUse += [{
      "matcher": "Bash",
      "hooks": [{ "type": "command", "command": $cmd, "timeout": 10 }]
    }]
    end
  ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
  say "  wired PreToolUse/Bash hook into settings.json (idempotent)"
}

unwire_hook() {
  [ -e "$HOOK_DEST" ] && { rm -f "$HOOK_DEST"; say "  removed $HOOK_DEST"; }
  [ -f "$CLAUDE_SETTINGS" ] || return 0
  command -v jq >/dev/null 2>&1 || { say "  jq not found — remove the orfi-kit PreToolUse entry from $CLAUDE_SETTINGS manually."; return 0; }
  jq empty "$CLAUDE_SETTINGS" >/dev/null 2>&1 || { say "  $CLAUDE_SETTINGS not valid JSON — leaving it untouched."; return 0; }

  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"
  local tmp; tmp="$(mktemp)"
  # Drop only entries whose hooks run our command; clean up empty containers.
  jq --arg cmd "$HOOK_CMD" '
    if (.hooks.PreToolUse | type) == "array" then
      .hooks.PreToolUse |= map(select(
        (.matcher == "Bash" and (any(.hooks[]?; .command == $cmd))) | not
      ))
    else . end
  ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
  say "  removed orfi-kit PreToolUse entry from settings.json"
}

print_manual_hook_json() {
  cat <<'JSON'
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-sync.sh\"", "timeout": 10 }
      ]
    }
JSON
}

# --- Brevity Stop hook: block over-long assistant replies ---------------------
# Wires a Stop hook (no matcher — Stop events are not tool-scoped) that runs the
# brevity enforcer. Idempotent; backs up settings.json first.

wire_brevity_hook() {
  place "$BREVITY_SRC" "$BREVITY_DEST"
  chmod +x "$BREVITY_DEST" 2>/dev/null || true

  if ! command -v jq >/dev/null 2>&1; then
    say ""
    say "  jq not found — cannot auto-wire settings.json. Add this manually to"
    say "  $CLAUDE_SETTINGS under .hooks.Stop:"
    print_manual_brevity_json
    return 0
  fi

  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [ -f "$CLAUDE_SETTINGS" ] || echo '{}' > "$CLAUDE_SETTINGS"

  if ! jq empty "$CLAUDE_SETTINGS" >/dev/null 2>&1; then
    say "  $CLAUDE_SETTINGS is not valid JSON — not touching it. Add manually:"
    print_manual_brevity_json
    return 0
  fi

  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"

  local tmp
  tmp="$(mktemp)"
  jq --arg cmd "$BREVITY_CMD" '
    .hooks //= {} |
    .hooks.Stop //= [] |
    if any(.hooks.Stop[]?; any(.hooks[]?; .command == $cmd))
    then .
    else .hooks.Stop += [{
      "hooks": [{ "type": "command", "command": $cmd, "timeout": 10 }]
    }]
    end
  ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
  say "  wired Stop brevity hook into settings.json (idempotent)"
}

unwire_brevity_hook() {
  [ -e "$BREVITY_DEST" ] && { rm -f "$BREVITY_DEST"; say "  removed $BREVITY_DEST"; }
  [ -f "$CLAUDE_SETTINGS" ] || return 0
  command -v jq >/dev/null 2>&1 || { say "  jq not found — remove the orfi-kit Stop entry from $CLAUDE_SETTINGS manually."; return 0; }
  jq empty "$CLAUDE_SETTINGS" >/dev/null 2>&1 || { say "  $CLAUDE_SETTINGS not valid JSON — leaving it untouched."; return 0; }

  cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.bak"
  local tmp; tmp="$(mktemp)"
  jq --arg cmd "$BREVITY_CMD" '
    if (.hooks.Stop | type) == "array" then
      .hooks.Stop |= map(select((any(.hooks[]?; .command == $cmd)) | not))
    else . end
  ' "$CLAUDE_SETTINGS" > "$tmp" && mv "$tmp" "$CLAUDE_SETTINGS"
  say "  removed orfi-kit Stop entry from settings.json"
}

print_manual_brevity_json() {
  cat <<'JSON'
    {
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh\"", "timeout": 10 }
      ]
    }
JSON
}

# --- NEW (beyond trackbed): Copilot extension --------------------------------
# Path verified from the Copilot CLI bundle: ~/.copilot/extensions/<name>/extension.mjs

install_copilot_extension() { place "$EXT_SRC" "$COPILOT_EXTS/orfi-kit-guardrails"; }
remove_copilot_extension() {
  if [ -e "$COPILOT_EXTS/orfi-kit-guardrails" ] || [ -L "$COPILOT_EXTS/orfi-kit-guardrails" ]; then
    rm -rf "$COPILOT_EXTS/orfi-kit-guardrails"; say "  removed $COPILOT_EXTS/orfi-kit-guardrails"
  fi
}

# --- arg parsing -------------------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --link)      LINK=1 ;;
    --uninstall) MODE="uninstall" ;;
    --help|-h)   usage ;;
    *)           err "unknown option: $arg (try --help)" ;;
  esac
done

[ -d "$SKILLS_SRC" ] || err "skills not found at $SKILLS_SRC — run this from the orfi-kit repo"

# --- runtime selection -------------------------------------------------------

WANT_CC=0; WANT_OC=0; WANT_CP=0

say "orfi-kit installer"
say "Install for which runtime(s)?"
say "  1) Claude Code"
say "  2) OpenCode"
say "  3) GitHub Copilot CLI"
say "Select one or more (e.g. '1', '3', or '1 2 3' / '1,2' for several)."
printf 'Choice: '
read -r choice

for n in ${choice//,/ }; do
  case "$n" in
    1) WANT_CC=1 ;;
    2) WANT_OC=1 ;;
    3) WANT_CP=1 ;;
    *) err "invalid choice: '$n' (pick 1, 2 and/or 3)" ;;
  esac
done

[ "$WANT_CC" -eq 1 ] || [ "$WANT_OC" -eq 1 ] || [ "$WANT_CP" -eq 1 ] || err "no runtime selected"

# --- uninstall ---------------------------------------------------------------

if [ "$MODE" = "uninstall" ]; then
  say ""
  say "Uninstalling orfi-kit..."
  if [ "$WANT_CC" -eq 1 ]; then
    remove_claude_skills_from "$CLAUDE_SKILLS"
    remove_commands_from "$CLAUDE_CMDS"
    unwire_hook
    unwire_brevity_hook
  fi
  if [ "$WANT_OC" -eq 1 ]; then
    remove_claude_skills_from "$OPENCODE_SKILLS"
    remove_commands_from "$OPENCODE_CMDS"
  fi
  if [ "$WANT_CP" -eq 1 ]; then
    remove_copilot_skills
    remove_copilot_extension
  fi
  say "Done."
  exit 0
fi

# --- install: skills + commands ----------------------------------------------

say ""

if [ "$WANT_CC" -eq 1 ] && [ "$WANT_OC" -eq 1 ]; then
  say "Claude Code + OpenCode — skills go to ~/.claude/skills (OpenCode reads it natively)."
  install_claude_skills_to "$CLAUDE_SKILLS"
  if have_claude_skills_in "$OPENCODE_SKILLS"; then
    say "Removing duplicate skills under OpenCode to avoid drift:"
    remove_claude_skills_from "$OPENCODE_SKILLS"
  fi
  install_commands_to "$CLAUDE_CMDS"
  install_commands_to "$OPENCODE_CMDS"
elif [ "$WANT_CC" -eq 1 ]; then
  install_claude_skills_to "$CLAUDE_SKILLS"
  install_commands_to "$CLAUDE_CMDS"
elif [ "$WANT_OC" -eq 1 ]; then
  if have_claude_skills_in "$CLAUDE_SKILLS"; then
    say "Found existing skills in ~/.claude/skills — OpenCode reads that path natively,"
    say "so skills are left there (not duplicated under OpenCode)."
  else
    install_claude_skills_to "$OPENCODE_SKILLS"
  fi
  install_commands_to "$OPENCODE_CMDS"
fi

# Hook + settings wiring: Claude Code only (OpenCode has no settings.json hooks model here).
if [ "$WANT_CC" -eq 1 ]; then
  say ""
  say "Installing sync-enforcement hook (Claude Code):"
  wire_hook
  say ""
  say "Installing brevity-enforcement Stop hook (Claude Code):"
  wire_brevity_hook
fi

# --- Copilot CLI (own source, own home, no command file) + extension ---------

if [ "$WANT_CP" -eq 1 ]; then
  say ""
  say "GitHub Copilot CLI — skills go to ~/.copilot/skills (the skill is its own slash command)."
  install_copilot_skills
  say "Installing Copilot guardrails extension to ~/.copilot/extensions:"
  install_copilot_extension
fi

say ""
say "Done. Invoke with /orfi-kit-commit or /orfi-kit-code-review"
