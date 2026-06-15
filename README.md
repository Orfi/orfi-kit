![orfi-kit](assets/header.png)

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
