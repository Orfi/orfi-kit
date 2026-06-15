# orfi-kit Assembly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Assemble the `orfi-kit` repository from existing source files and build its cross-platform installer pair, per `orfi-kit-PRD.md`.

**Architecture:** Copy a fixed manifest of skills/commands/hook/extension from `ai-augmented-dev-resources` into a `claude/` + `copilot/` repo layout. Adapt the trackbed `install.sh` / `install.ps1` pair, adding two genuinely new capabilities: a `settings.json` PreToolUse hook wiring (idempotent, merge-safe, backed up) and a Copilot extension install. Verify both installers by dry-running into a temp `HOME`.

**Tech Stack:** Bash, PowerShell (pwsh), `jq` (bash JSON merge), Markdown. No runtime code beyond the one hook + one extension.

**Key resolved facts (from research, not assumption):**
- Copilot extensions path is **`~/.copilot/extensions/<name>/extension.mjs`** — confirmed from the Copilot CLI's own bundled code (string: *"Extension discovered from the user's ~/.copilot/extensions directory"*; example path `extensions/my-extension/extension.mjs`).
- Source repo: `/mnt/BA707A64707A2773/code/ai-augmented-dev-resources`
- Reference installers: `/mnt/BA707A64707A2773/code/trackbed/install.{sh,ps1}`
- Target repo: `/mnt/BA707A64707A2773/code/orfi-kit` (branch `main`, no Jira ticket)
- `jq` is available at `/home/orfi/anaconda3/bin/jq`.

**Conventions (orfi-git-conventions skill):** Commit subjects use an uppercase verb prefix (`ADDED`, `FIXED`, `IMPROVED`, etc.). No ticket ID (no Jira project). Commit directly to `main`.

---

## File Structure

Repo layout to be created under `/mnt/BA707A64707A2773/code/orfi-kit/`:

```
claude/
  commands/   <- 10 orfi-kit-*.md + orfi-kit-sync-branch.README.md (repo docs only)
  skills/     <- 4 orfi-kit-* skill dirs
  hooks/      <- orfi-kit-enforce-sync.sh
copilot/
  skills/     <- 14 orfi-kit-* skill dirs
  extensions/ <- orfi-kit-guardrails/extension.mjs
install.sh
install.ps1
README.md
LICENSE        (already present, MIT)
orfi-kit-PRD.md  (already present)
docs/superpowers/...  (planning artifacts)
```

Responsibilities:
- `claude/` — Claude Code / OpenCode surface (skills + commands + hook).
- `copilot/` — Copilot CLI surface (14 skills + 1 extension).
- `install.sh` / `install.ps1` — behaviorally-equivalent install-time plumbing.
- `README.md` — what-it-is, per-item list, install/uninstall both forms, hook + extension notes.

---

## Task 1: Copy the Claude Code surface (skills, commands, hook)

**Files:**
- Create: `claude/skills/{orfi-kit-git-conventions,orfi-kit-guardrails,orfi-kit-scrum-poker,orfi-kit-xml-docs}/`
- Create: `claude/commands/orfi-kit-{code-review,commit,enforce-guardrails,load-state,persist-state,run-codegraph-phase,run-integration-tests-phase,run-unit-tests-phase,sync-branch,sync-master}.md`
- Create: `claude/commands/orfi-kit-sync-branch.README.md`
- Create: `claude/hooks/orfi-kit-enforce-sync.sh`

- [ ] **Step 1: Create target dirs**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
mkdir -p claude/skills claude/commands claude/hooks
```

- [ ] **Step 2: Copy the 4 Claude skill dirs (exclude panviva-xml-docs)**

```bash
SRC=/mnt/BA707A64707A2773/code/ai-augmented-dev-resources/claude-tools
for s in orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-scrum-poker orfi-kit-xml-docs; do
  cp -R "$SRC/skills/$s" claude/skills/
done
```

- [ ] **Step 3: Copy the 10 command files + the README companion (exclude orfi-ae-kit-*, orfi-gsd-secure-phase, orfi-update-gsd-state-phase)**

```bash
SRC=/mnt/BA707A64707A2773/code/ai-augmented-dev-resources/claude-tools
for c in orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails \
         orfi-kit-load-state orfi-kit-persist-state orfi-kit-run-codegraph-phase \
         orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase \
         orfi-kit-sync-branch orfi-kit-sync-master; do
  cp "$SRC/commands/$c.md" claude/commands/
done
cp "$SRC/commands/orfi-kit-sync-branch.README.md" claude/commands/
```

- [ ] **Step 4: Copy the hook and keep it executable**

```bash
SRC=/mnt/BA707A64707A2773/code/ai-augmented-dev-resources/claude-tools
cp "$SRC/hooks/orfi-kit-enforce-sync.sh" claude/hooks/
chmod +x claude/hooks/orfi-kit-enforce-sync.sh
```

- [ ] **Step 5: Verify counts and exclusions**

```bash
echo "skills (want 4):"   && ls claude/skills | wc -l
echo "commands .md (want 10):" && ls claude/commands/orfi-kit-*.md | grep -v README | wc -l
echo "README companion (want 1):" && ls claude/commands/*.README.md | wc -l
echo "hook (want 1):" && ls claude/hooks | wc -l
echo "exclusions (want 0):" && grep -rli -E 'panviva|orfi-ae-kit|orfi-gsd-secure|orfi-update-gsd-state' claude/ | wc -l
```
Expected: `4`, `10`, `1`, `1`, `0`.

- [ ] **Step 6: Commit**

```bash
git add claude/
git commit -m "ADDED Claude Code surface (4 skills, 10 commands, sync hook)"
```

---

## Task 2: Copy the Copilot surface (14 skills, 1 extension)

**Files:**
- Create: `copilot/skills/` — 14 `orfi-kit-*` skill dirs
- Create: `copilot/extensions/orfi-kit-guardrails/extension.mjs`

- [ ] **Step 1: Create target dirs**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
mkdir -p copilot/skills copilot/extensions
```

- [ ] **Step 2: Copy the 14 Copilot skill dirs (exclude panviva-xml-docs, orfi-ae-kit-*)**

```bash
SRC=/mnt/BA707A64707A2773/code/ai-augmented-dev-resources/copilot-tools
for s in orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails \
         orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-load-state \
         orfi-kit-persist-state orfi-kit-run-codegraph-phase \
         orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase \
         orfi-kit-scrum-poker orfi-kit-sync-branch orfi-kit-sync-master \
         orfi-kit-xml-docs; do
  cp -R "$SRC/skills/$s" copilot/skills/
done
```

- [ ] **Step 3: Copy the extension**

```bash
SRC=/mnt/BA707A64707A2773/code/ai-augmented-dev-resources/copilot-tools
cp -R "$SRC/extensions/orfi-kit-guardrails" copilot/extensions/
```

- [ ] **Step 4: Verify counts and exclusions**

```bash
echo "copilot skills (want 14):" && ls copilot/skills | wc -l
echo "extension.mjs (want 1):" && ls copilot/extensions/orfi-kit-guardrails/extension.mjs | wc -l
echo "exclusions (want 0):" && grep -rli -E 'panviva|orfi-ae-kit' copilot/ | wc -l
```
Expected: `14`, `1`, `0`.

- [ ] **Step 5: Commit**

```bash
git add copilot/
git commit -m "ADDED Copilot CLI surface (14 skills, guardrails extension)"
```

---

## Task 3: Write `install.sh`

**Files:**
- Create: `install.sh`

The script is adapted from `/mnt/BA707A64707A2773/code/trackbed/install.sh`. Differences from trackbed:
- `SKILLS` array = 14 Copilot names; `CLAUDE_SKILLS_NAMES` = the 4 Claude skill dirs; `COMMANDS` = 10 command file basenames.
- New: `wire_hook()` / `unwire_hook()` for `settings.json` (jq merge, idempotent, backup).
- New: Copilot extension install to `~/.copilot/extensions/`.
- `.README.md` is never installed (the COMMANDS array lists only the 10 files).

- [ ] **Step 1: Write `install.sh`**

```bash
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
# Claude Code + OpenCode share one skill source (claude/skills) and the 10
# command files (claude/commands). Copilot uses its OWN source (copilot/skills,
# 14 dirs) and its own home (~/.copilot/skills) — no command file (in Copilot a
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

# The 4 Claude skill dirs (shared by Claude Code + OpenCode).
CLAUDE_SKILL_NAMES=(orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-scrum-poker orfi-kit-xml-docs)

# The 14 Copilot skill dirs.
COPILOT_SKILL_NAMES=(
  orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails
  orfi-kit-git-conventions orfi-kit-guardrails orfi-kit-load-state
  orfi-kit-persist-state orfi-kit-run-codegraph-phase
  orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase
  orfi-kit-scrum-poker orfi-kit-sync-branch orfi-kit-sync-master
  orfi-kit-xml-docs
)

# The 10 command files (Claude Code / OpenCode only). NOTE: the .README.md
# companion is deliberately NOT listed — it is repo docs, not a runtime command.
COMMAND_NAMES=(
  orfi-kit-code-review orfi-kit-commit orfi-kit-enforce-guardrails
  orfi-kit-load-state orfi-kit-persist-state orfi-kit-run-codegraph-phase
  orfi-kit-run-integration-tests-phase orfi-kit-run-unit-tests-phase
  orfi-kit-sync-branch orfi-kit-sync-master
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
```

- [ ] **Step 2: Make it executable**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
chmod +x install.sh
```

- [ ] **Step 3: Syntax check**

Run: `bash -n install.sh && echo "syntax OK"`
Expected: `syntax OK`

- [ ] **Step 4: Help check**

Run: `./install.sh --help`
Expected: usage text printed (lines from the header), exit 0.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "ADDED bash installer with hook wiring and Copilot extension support"
```

---

## Task 4: Dry-run `install.sh` into a temp HOME (verify behavior)

**Files:** none (verification only)

This proves copy, link, settings.json merge (idempotent + backup), and uninstall actually work, without touching the real `~`.

- [ ] **Step 1: Claude-only install into temp HOME**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
T=$(mktemp -d)
# feed '1' for runtime choice, 'n' to decline auto-wire on this pass
printf '1\nn\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh || true
echo "--- skills (want 4) ---"; ls "$T/.claude/skills" | wc -l
echo "--- commands (want 10, no README) ---"; ls "$T/.claude/commands" | wc -l; ls "$T/.claude/commands" | grep -c README || true
echo "--- hook present ---"; ls "$T/.claude/hooks/orfi-kit-enforce-sync.sh"
echo "$T" > /tmp/orfi_test_home
```
Expected: `4`; `10`; README count `0`; hook path listed.

- [ ] **Step 2: Auto-wire settings.json on a fresh file and check idempotency**

```bash
T=$(mktemp -d)
mkdir -p "$T/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]}}' > "$T/.claude/settings.json"
# Run twice with auto-wire = Y; second run must NOT duplicate the entry.
printf '1\nY\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh >/dev/null 2>&1 || true
printf '1\nY\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh >/dev/null 2>&1 || true
echo "--- PreToolUse entries running our hook (want 1) ---"
jq '[.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]? | select(.command|test("orfi-kit-enforce-sync"))] | length' "$T/.claude/settings.json"
echo "--- permissions preserved (want Bash(ls:*)) ---"
jq -r '.permissions.allow[0]' "$T/.claude/settings.json"
echo "--- backup exists ---"; ls "$T/.claude/settings.json.bak"
echo "$T" > /tmp/orfi_test_home2
```
Expected: `1` (not 2 — idempotent); `Bash(ls:*)` (existing config preserved); backup listed.

- [ ] **Step 3: Uninstall removes skills, commands, hook, and the settings entry**

```bash
T=$(cat /tmp/orfi_test_home2)
printf '1\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh --uninstall >/dev/null 2>&1 || true
echo "--- skills remaining (want 0) ---"; ls "$T/.claude/skills" 2>/dev/null | wc -l
echo "--- hook remaining (want 0) ---"; ls "$T/.claude/hooks/orfi-kit-enforce-sync.sh" 2>/dev/null | wc -l
echo "--- settings entries running our hook (want 0) ---"
jq '[.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]? | select(.command|test("orfi-kit-enforce-sync"))] | length' "$T/.claude/settings.json"
echo "--- permissions still preserved ---"; jq -r '.permissions.allow[0]' "$T/.claude/settings.json"
```
Expected: `0`; `0`; `0`; `Bash(ls:*)`.

- [ ] **Step 4: Copilot-only install places skills + extension at verified path**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
T=$(mktemp -d)
printf '3\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh >/dev/null 2>&1 || true
echo "--- copilot skills (want 14) ---"; ls "$T/.copilot/skills" | wc -l
echo "--- extension at verified path ---"; ls "$T/.copilot/extensions/orfi-kit-guardrails/extension.mjs"
```
Expected: `14`; extension.mjs path listed.

- [ ] **Step 5: `--link` mode creates symlinks**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
T=$(mktemp -d)
printf '1\nn\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" ./install.sh --link >/dev/null 2>&1 || true
echo "--- skill is a symlink (want 'link') ---"
[ -L "$T/.claude/skills/orfi-kit-guardrails" ] && echo "link" || echo "NOT A LINK"
```
Expected: `link`.

- [ ] **Step 6: Clean up temp homes**

```bash
for f in /tmp/orfi_test_home /tmp/orfi_test_home2; do [ -f "$f" ] && rm -rf "$(cat $f)" && rm -f "$f"; done
echo "cleaned"
```

If any expected value above does not match, STOP and fix `install.sh` before proceeding. Report the actual numbers.

---

## Task 5: Write `install.ps1` (behavioral twin of install.sh)

**Files:**
- Create: `install.ps1`

Adapted from `/mnt/BA707A64707A2773/code/trackbed/install.ps1`, mirroring every behavior of `install.sh` including the new hook wiring (via `ConvertFrom-Json` / `ConvertTo-Json -Depth 100`) and Copilot extension install.

- [ ] **Step 1: Write `install.ps1`**

```powershell
#!/usr/bin/env pwsh
#
# orfi-kit installer (PowerShell) — the cross-platform twin of install.sh.
# Runs on Windows PowerShell 5+, and pwsh on Windows / macOS / Linux.
#
# orfi-kit is skills/markdown plus one hook and one Copilot extension. This
# script is install-time plumbing only.
#
# Usage:
#   ./install.ps1                 interactive: asks which runtime(s) to install for
#   ./install.ps1 -Link           symlink instead of copy (dev: repo edits go live)
#   ./install.ps1 -Uninstall      remove an existing orfi-kit install
#   ./install.ps1 -Help           show this help
#
# Claude Code + OpenCode share one skill source (claude/skills) and the 10
# command files. Copilot uses its own source (copilot/skills) and its own home
# (~/.copilot/skills). settings.json file-mode is only meaningful on POSIX.

[CmdletBinding()]
param(
    [switch]$Link,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- paths -------------------------------------------------------------------

$RepoDir          = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc        = Join-Path $RepoDir 'claude/skills'
$CopilotSkillsSrc = Join-Path $RepoDir 'copilot/skills'
$CmdsSrc          = Join-Path $RepoDir 'claude/commands'
$HookSrc          = Join-Path $RepoDir 'claude/hooks/orfi-kit-enforce-sync.sh'
$ExtSrc           = Join-Path $RepoDir 'copilot/extensions/orfi-kit-guardrails'

$Home_     = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $Home_ '.config' }

$ClaudeSkills   = Join-Path $Home_ '.claude/skills'
$ClaudeCmds     = Join-Path $Home_ '.claude/commands'
$ClaudeHooks    = Join-Path $Home_ '.claude/hooks'
$ClaudeSettings = Join-Path $Home_ '.claude/settings.json'
$OpencodeSkills = Join-Path $XdgConfig 'opencode/skills'
$OpencodeCmds   = Join-Path $XdgConfig 'opencode/commands'
$CopilotSkills  = Join-Path $Home_ '.copilot/skills'
$CopilotExts    = Join-Path $Home_ '.copilot/extensions'   # verified from Copilot CLI bundle

$HookDest = Join-Path $ClaudeHooks 'orfi-kit-enforce-sync.sh'
$HookCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-enforce-sync.sh"'

$ClaudeSkillNames = @('orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-scrum-poker','orfi-kit-xml-docs')

$CopilotSkillNames = @(
  'orfi-kit-code-review','orfi-kit-commit','orfi-kit-enforce-guardrails',
  'orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-load-state',
  'orfi-kit-persist-state','orfi-kit-run-codegraph-phase',
  'orfi-kit-run-integration-tests-phase','orfi-kit-run-unit-tests-phase',
  'orfi-kit-scrum-poker','orfi-kit-sync-branch','orfi-kit-sync-master',
  'orfi-kit-xml-docs'
)

# 10 command files — .README.md companion deliberately excluded.
$CommandNames = @(
  'orfi-kit-code-review','orfi-kit-commit','orfi-kit-enforce-guardrails',
  'orfi-kit-load-state','orfi-kit-persist-state','orfi-kit-run-codegraph-phase',
  'orfi-kit-run-integration-tests-phase','orfi-kit-run-unit-tests-phase',
  'orfi-kit-sync-branch','orfi-kit-sync-master'
)

# --- helpers -----------------------------------------------------------------

function Say($msg) { Write-Host $msg }
function Die($msg) { Write-Error "error: $msg"; exit 1 }

function Show-Usage {
    Get-Content $MyInvocation.PSCommandPath | Select-Object -Skip 2 -First 17 |
        ForEach-Object { $_ -replace '^#$','' -replace '^# ','' }
    exit 0
}

function Place($src, $dest) {
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    if ($Link) {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
        Say "  linked  $dest"
    } else {
        Copy-Item -Recurse -Force $src $dest
        Say "  copied  $dest"
    }
}

function Install-ClaudeSkillsTo($targetDir) {
    foreach ($s in $ClaudeSkillNames) { Place (Join-Path $SkillsSrc $s) (Join-Path $targetDir $s) }
}
function Remove-ClaudeSkillsFrom($targetDir) {
    foreach ($s in $ClaudeSkillNames) {
        $p = Join-Path $targetDir $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}
function Install-CommandsTo($targetDir) {
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    foreach ($c in $CommandNames) { Place (Join-Path $CmdsSrc "$c.md") (Join-Path $targetDir "$c.md") }
}
function Remove-CommandsFrom($targetDir) {
    foreach ($c in $CommandNames) {
        $p = Join-Path $targetDir "$c.md"
        if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
    }
}
function Install-CopilotSkills {
    foreach ($s in $CopilotSkillNames) { Place (Join-Path $CopilotSkillsSrc $s) (Join-Path $CopilotSkills $s) }
}
function Remove-CopilotSkills {
    foreach ($s in $CopilotSkillNames) {
        $p = Join-Path $CopilotSkills $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}
function Test-ClaudeSkillsIn($dir) { Test-Path (Join-Path $dir 'orfi-kit-guardrails/SKILL.md') }

# --- NEW: settings.json hook wiring ------------------------------------------

function Get-ManualHookText {
@'
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-sync.sh\"", "timeout": 10 }
      ]
    }
'@
}

function Wire-Hook {
    Place $HookSrc $HookDest

    $reply = Read-Host "  Wire the hook into $ClaudeSettings automatically? [Y/n]"
    if ($reply -match '^[Nn]') {
        Say "  Skipped. Add this to .hooks.PreToolUse manually:"; Say (Get-ManualHookText); return
    }

    $dir = Split-Path -Parent $ClaudeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $ClaudeSettings)) { '{}' | Set-Content -Path $ClaudeSettings }

    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings is not valid JSON — not touching it. Add manually:"; Say (Get-ManualHookText); return }

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
    Say "  backed up $ClaudeSettings -> $ClaudeSettings.bak"

    if (-not $json.hooks) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $json.hooks.PreToolUse) { $json.hooks | Add-Member -NotePropertyName PreToolUse -NotePropertyValue @() -Force }

    $already = @($json.hooks.PreToolUse | Where-Object {
        $_.matcher -eq 'Bash' -and ($_.hooks | Where-Object { $_.command -eq $HookCmd })
    }).Count -gt 0

    if ($already) {
        Say "  hook already wired — leaving settings.json unchanged (idempotent)"
    } else {
        $entry = [pscustomobject]@{
            matcher = 'Bash'
            hooks   = @([pscustomobject]@{ type = 'command'; command = $HookCmd; timeout = 10 })
        }
        $json.hooks.PreToolUse = @($json.hooks.PreToolUse) + $entry
        ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
        Say "  wired PreToolUse/Bash hook into settings.json"
    }
}

function Unwire-Hook {
    if (Test-Path $HookDest) { Remove-Item -Force $HookDest; Say "  removed $HookDest" }
    if (-not (Test-Path $ClaudeSettings)) { return }
    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks -or -not $json.hooks.PreToolUse) { return }

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
    $kept = @($json.hooks.PreToolUse | Where-Object {
        -not ($_.matcher -eq 'Bash' -and ($_.hooks | Where-Object { $_.command -eq $HookCmd }))
    })
    $json.hooks.PreToolUse = $kept
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit PreToolUse entry from settings.json"
}

# --- NEW: Copilot extension (verified path ~/.copilot/extensions) ------------

function Install-CopilotExtension { Place $ExtSrc (Join-Path $CopilotExts 'orfi-kit-guardrails') }
function Remove-CopilotExtension {
    $p = Join-Path $CopilotExts 'orfi-kit-guardrails'
    if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
}

# --- arg parsing -------------------------------------------------------------

if ($Help) { Show-Usage }
if (-not (Test-Path $SkillsSrc)) { Die "skills not found at $SkillsSrc - run this from the orfi-kit repo" }

# --- runtime selection -------------------------------------------------------

$WantCC = $false; $WantOC = $false; $WantCP = $false

Say 'orfi-kit installer'
Say 'Install for which runtime(s)?'
Say '  1) Claude Code'
Say '  2) OpenCode'
Say '  3) GitHub Copilot CLI'
Say "Select one or more (e.g. '1', '3', or '1 2 3' / '1,2' for several)."
$choice = Read-Host 'Choice'

foreach ($n in ($choice -split '[,\s]+' | Where-Object { $_ -ne '' })) {
    switch ($n) {
        '1' { $WantCC = $true }
        '2' { $WantOC = $true }
        '3' { $WantCP = $true }
        default { Die "invalid choice: '$n' (pick 1, 2 and/or 3)" }
    }
}
if (-not ($WantCC -or $WantOC -or $WantCP)) { Die 'no runtime selected' }

# --- uninstall ---------------------------------------------------------------

if ($Uninstall) {
    Say ''
    Say 'Uninstalling orfi-kit...'
    if ($WantCC) { Remove-ClaudeSkillsFrom $ClaudeSkills; Remove-CommandsFrom $ClaudeCmds; Unwire-Hook }
    if ($WantOC) { Remove-ClaudeSkillsFrom $OpencodeSkills; Remove-CommandsFrom $OpencodeCmds }
    if ($WantCP) { Remove-CopilotSkills; Remove-CopilotExtension }
    Say 'Done.'
    exit 0
}

# --- install: skills + commands ----------------------------------------------

Say ''

if ($WantCC -and $WantOC) {
    Say 'Claude Code + OpenCode - skills go to ~/.claude/skills (OpenCode reads it natively).'
    Install-ClaudeSkillsTo $ClaudeSkills
    if (Test-ClaudeSkillsIn $OpencodeSkills) {
        Say 'Removing duplicate skills under OpenCode to avoid drift:'
        Remove-ClaudeSkillsFrom $OpencodeSkills
    }
    Install-CommandsTo $ClaudeCmds
    Install-CommandsTo $OpencodeCmds
}
elseif ($WantCC) {
    Install-ClaudeSkillsTo $ClaudeSkills
    Install-CommandsTo $ClaudeCmds
}
elseif ($WantOC) {
    if (Test-ClaudeSkillsIn $ClaudeSkills) {
        Say 'Found existing skills in ~/.claude/skills - OpenCode reads that path natively,'
        Say 'so skills are left there (not duplicated under OpenCode).'
    } else {
        Install-ClaudeSkillsTo $OpencodeSkills
    }
    Install-CommandsTo $OpencodeCmds
}

if ($WantCC) {
    Say ''
    Say 'Installing sync-enforcement hook (Claude Code):'
    Wire-Hook
}

# --- Copilot CLI + extension -------------------------------------------------

if ($WantCP) {
    Say ''
    Say 'GitHub Copilot CLI - skills go to ~/.copilot/skills (the skill is its own slash command).'
    Install-CopilotSkills
    Say 'Installing Copilot guardrails extension to ~/.copilot/extensions:'
    Install-CopilotExtension
}

Say ''
Say 'Done. Invoke with /orfi-kit-commit or /orfi-kit-code-review'
```

- [ ] **Step 2: Syntax check (if pwsh available)**

Run: `command -v pwsh && pwsh -NoProfile -Command "& { \$null = [System.Management.Automation.Language.Parser]::ParseFile('install.ps1', [ref]\$null, [ref]\$null); 'parse OK' }"`
Expected: `parse OK`. If `pwsh` is not installed, note that explicitly and skip — do not claim it passed.

- [ ] **Step 3: Commit**

```bash
git add install.ps1
git commit -m "ADDED PowerShell installer twin with parity to install.sh"
```

---

## Task 6: Dry-run `install.ps1` into a temp HOME (if pwsh available)

**Files:** none (verification only)

- [ ] **Step 1: Detect pwsh**

Run: `command -v pwsh || echo "NO pwsh"`
If `NO pwsh`: record in the final report that PowerShell dry-run was **not performed** because pwsh is unavailable, and that parity was verified by code review against the bash twin instead. Skip remaining steps.

- [ ] **Step 2: Copilot-only install (no prompts beyond choice)**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
T=$(mktemp -d)
printf '3\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" pwsh -NoProfile -File ./install.ps1 >/dev/null 2>&1 || true
echo "--- copilot skills (want 14) ---"; ls "$T/.copilot/skills" | wc -l
echo "--- extension ---"; ls "$T/.copilot/extensions/orfi-kit-guardrails/extension.mjs"
rm -rf "$T"
```
Expected: `14`; extension.mjs listed.

- [ ] **Step 3: Claude install + settings.json merge + idempotency**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
T=$(mktemp -d); mkdir -p "$T/.claude"
printf '{"permissions":{"allow":["Bash(ls:*)"]}}' > "$T/.claude/settings.json"
printf '1\nY\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" pwsh -NoProfile -File ./install.ps1 >/dev/null 2>&1 || true
printf '1\nY\n' | HOME="$T" XDG_CONFIG_HOME="$T/.config" pwsh -NoProfile -File ./install.ps1 >/dev/null 2>&1 || true
echo "--- entries running our hook (want 1) ---"
jq '[.hooks.PreToolUse[]? | select(.matcher=="Bash") | .hooks[]? | select(.command|test("orfi-kit-enforce-sync"))] | length' "$T/.claude/settings.json"
echo "--- permissions preserved ---"; jq -r '.permissions.allow[0]' "$T/.claude/settings.json"
rm -rf "$T"
```
Expected: `1`; `Bash(ls:*)`.

If values differ, STOP and fix `install.ps1`. Report actual numbers.

---

## Task 7: Write `README.md`

**Files:**
- Modify: `README.md` (currently a one-line stub `# orfi-kit`)

Per PRD §6, the README must cover: what orfi-kit is (+ orfi-ae-kit note), per-item descriptions, install/uninstall in both bash and PowerShell forms, sync-branch docs pointer, hook + extension notes.

- [ ] **Step 1: Read the current README first**

Run: `cat README.md`
Expected: `# orfi-kit` (stub). (Read before overwriting — guardrail.)

- [ ] **Step 2: Write the README**

```markdown
# orfi-kit

A generic, reusable bundle of **Claude Code + GitHub Copilot CLI** skills, commands, and hooks for
AI-augmented development. It packages a team's day-to-day automation — git conventions, guardrails,
commits, code review, session state, test runners, Jira estimation, C# XML-doc rules, and branch
sync — and installs them flat (every item is prefixed `orfi-kit-`).

> **Related kit:** `orfi-ae-kit` (the Architect/Executor pattern) is a **separate** repo that lists
> orfi-kit as a prerequisite. This repo is only orfi-kit.

## What's inside

### Skills (Claude Code / OpenCode) & slash commands (Copilot)

- **orfi-kit-git-conventions** — commit / branch / PR naming format.
- **orfi-kit-guardrails** — always-active behavioral constraints (honesty, safe VCS, clarity).
- **orfi-kit-scrum-poker** — Fibonacci-estimate a Jira ticket via the Atlassian MCP server.
- **orfi-kit-xml-docs** — enforce client-neutral C# XML documentation.

### Commands (Claude Code / OpenCode) — also Copilot slash commands

- **orfi-kit-enforce-guardrails** — re-assert the guardrails when behavior drifts.
- **orfi-kit-commit** — assemble and write a conventional commit.
- **orfi-kit-code-review** — structured review of the current diff.
- **orfi-kit-load-state** / **orfi-kit-persist-state** — load / save session context.
- **orfi-kit-run-unit-tests-phase** / **orfi-kit-run-integration-tests-phase** /
  **orfi-kit-run-codegraph-phase** — run the respective test phase.
- **orfi-kit-sync-branch** / **orfi-kit-sync-master** — keep a feature branch synced with its parent epic.

### Hook (Claude Code)

- **orfi-kit-enforce-sync.sh** — a PreToolUse/Bash hook that **blocks `git push`** when a
  `feature/*` branch is out of sync with its parent epic. Pairs with `orfi-kit-sync-branch`.
  Deeper docs: `claude/commands/orfi-kit-sync-branch.README.md`.

### Extension (Copilot CLI)

- **orfi-kit-guardrails** (`extension.mjs`) — a Copilot SDK session extension that injects the
  guardrails as always-active context. Installs to `~/.copilot/extensions/orfi-kit-guardrails/`.

## Install

The repo ships two equivalent installers (a maintenance pair). Run either and pick which
runtime(s) you want (Claude Code, OpenCode, GitHub Copilot CLI — one or several).

**bash:**

    ./install.sh              # interactive install
    ./install.sh --link       # symlink instead of copy (dev: repo edits go live)
    ./install.sh --uninstall  # remove an existing install
    ./install.sh --help       # usage

**PowerShell (pwsh on Windows / macOS / Linux):**

    ./install.ps1             # interactive install
    ./install.ps1 -Link       # symlink instead of copy
    ./install.ps1 -Uninstall  # remove an existing install
    ./install.ps1 -Help       # usage

### Hook wiring (Claude Code)

When you install for Claude Code, the installer places `orfi-kit-enforce-sync.sh` in
`~/.claude/hooks/` and offers to wire it into `~/.claude/settings.json` as a PreToolUse/Bash hook.
The merge is **idempotent** and **non-destructive**: your existing settings are preserved and a
`settings.json.bak` backup is written before any change. Decline the prompt to get manual wiring
instructions instead. Uninstall removes both the hook file and the settings entry.

> Auto-wiring requires `jq` (bash) — without it you'll get manual instructions. PowerShell uses
> built-in JSON support.

### Copilot extension

When you install for GitHub Copilot CLI, the guardrails extension is copied to
`~/.copilot/extensions/orfi-kit-guardrails/` (the path the Copilot CLI loads user extensions from).

## Uninstall

Run the same installer with `--uninstall` (bash) or `-Uninstall` (PowerShell) and select the same
runtime(s). Skills, commands, the hook + its settings entry, and the Copilot extension are removed.

## License

MIT — see `LICENSE`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "ADDED README documenting skills, install flags, hook wiring, and extension"
```

---

## Task 8: Final acceptance verification (PRD §7)

**Files:** none (verification only)

- [ ] **Step 1: Structural counts**

```bash
cd /mnt/BA707A64707A2773/code/orfi-kit
echo "claude/skills (want 4):"     && ls claude/skills | wc -l
echo "copilot/skills (want 14):"   && ls copilot/skills | wc -l
echo "claude/commands .md w/o README (want 10):" && ls claude/commands/orfi-kit-*.md | grep -v README | wc -l
echo "README companion (want 1):"  && ls claude/commands/*.README.md | wc -l
echo "hook (want 1):"              && ls claude/hooks/orfi-kit-enforce-sync.sh | wc -l
echo "extension (want 1):"         && ls copilot/extensions/orfi-kit-guardrails/extension.mjs | wc -l
```
Expected: `4`, `14`, `10`, `1`, `1`, `1`.

- [ ] **Step 2: No client-specific / out-of-scope content (PRD §7 + §3.6)**

```bash
echo "must be empty:"
grep -ril -E 'panviva|panv|vivabank' . --include='*.md' --include='*.sh' --include='*.ps1' --include='*.mjs' | grep -v docs/superpowers || echo "OK: no client content"
echo "no excluded items:"
ls claude/commands copilot/skills 2>/dev/null | grep -E 'orfi-ae-kit|orfi-gsd-secure|orfi-update-gsd-state|scrum-poker-workspace' || echo "OK: no excluded items"
```
Expected: `OK: no client content`; `OK: no excluded items`.

> NOTE: The PRD §7 grep `panviva|panv|vivabank` may legitimately match the PRD file and these
> planning docs (which quote the exclusion list). Scope the check to shipped files; if a match
> appears outside `orfi-kit-PRD.md` / `docs/`, that's a real failure — report it.

- [ ] **Step 3: Installer parity sanity (both reference the same name lists)**

```bash
echo "install.sh Copilot skill count:"; grep -A20 'COPILOT_SKILL_NAMES=(' install.sh | grep -oE 'orfi-kit-[a-z-]+' | sort -u | wc -l
echo "install.ps1 Copilot skill count:"; grep -A20 'CopilotSkillNames = @(' install.ps1 | grep -oE 'orfi-kit-[a-z-]+' | sort -u | wc -l
```
Expected: both `14`.

- [ ] **Step 4: Report final acceptance status**

Walk the PRD §7 checklist out loud, marking each item PASS/FAIL with the evidence gathered above. If anything is FAIL, fix it before declaring done. Report real numbers — not "all good".

- [ ] **Step 5: Final commit if any fixes were made**

```bash
git add -A && git commit -m "FIXED acceptance verification follow-ups" || echo "nothing to commit"
git log --oneline -8
```

---

## Notes / Out of scope

- **No Jira ticket / working on `main`** per user — commits go directly to main, no ticket IDs.
- **Pre-existing finding (not in scope):** the user's real `~/.claude/settings.json` contains
  plaintext AWS keys. Flagged to the user; the installer testing uses a temp HOME and never touches
  the real file.
- The OpenCode runtime has no `settings.json` hook wiring in this kit (the hook is Claude Code
  specific, matching where `~/.claude/hooks` lives); OpenCode still gets skills + commands.
