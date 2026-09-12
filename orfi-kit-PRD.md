# orfi-kit — PRD / Onboarding Build Guide

> **Audience:** A future Claude Code session with **no prior context**. This document is the
> complete, self-contained spec for assembling the **orfi-kit** repository from existing source
> files and building its installer. Read it top to bottom before acting.

---

## 1. Purpose

**orfi-kit** is a generic, reusable bundle of **Claude Code, GitHub Copilot CLI, OpenCode, and
OpenAI Codex CLI** skills, commands, and hooks for AI-augmented development. It packages a team's
day-to-day automation:

- **git conventions** — commit message / branch / PR naming format
- **guardrails** — foundational behavioral constraints (honesty, safe VCS, clear comms)
- **commit** — assemble and write a conventional commit
- **code review** — structured review of a diff, plus C#- and C++-specific reviews that run the
  enforcing tools and ground style verdicts in the repo's own config
- **session state** — persist / load working context across sessions
- **test runners** — unit, integration, and codegraph phase test commands
- **scrum-poker** — Fibonacci planning-poker estimation of Jira tickets (via Atlassian MCP)
- **C# XML-doc enforcement** — XML documentation rules
- **C++ Doxygen-doc enforcement** — header-only Doxygen documentation rules (+ check script)
- **branch sync** — keep a feature branch in sync with its parent epic, enforced by a push hook
- **brevity enforcement** — cap replies at about one page, enforced by a Stop hook

It is **one of two kits**:

| Kit | What it is | Relationship |
|---|---|---|
| **orfi-kit** (this PRD) | The generic, reusable kit. | Standalone. |
| **orfi-ae-kit** | The Architect/Executor pattern (a separate kit). | A **SEPARATE repo** that lists orfi-kit as a **prerequisite**. |

**This PRD is ONLY for orfi-kit.** Do not pull any `orfi-ae-kit-*` items into this repo.

### Naming scheme

Every item is prefixed **`orfi-kit-`**. Everything installs **flat** (no nesting), so invocation
is uniform across the kit — e.g. `/orfi-kit-commit`, `/orfi-kit-code-review`,
`/orfi-kit-scrum-poker` (Codex invokes the same skills by bare name or description match instead
of a slash prefix).

---

## 2. Source location (where to copy FROM)

All source files currently live in:

```
/mnt/BA707A64707A2773/code/ai-augmented-dev-resources
```

…split by runtime:

- **Claude Code surface:**
  - `claude-tools/commands/`
  - `claude-tools/skills/`
  - `claude-tools/hooks/`
- **Copilot surface:**
  - `copilot-tools/skills/`
  - `copilot-tools/extensions/`

> **Note:** A **clean-slate copy is fine** — git history need **NOT** be preserved. Just copy the
> files listed in the manifest below into the new repo layout.

> **Heads-up:** The source repo also contains `orfi-ae-kit-*` files and a few out-of-scope
> files. Those are **excluded** (see §3). Copy **only** the files explicitly listed.

---

## 3. Exact file manifest for orfi-kit

Copy **exactly** these files/directories. Nothing more, nothing less.

### 3.1 Claude Code — commands (from `claude-tools/commands/`)

Command files (installed to the runtime) — **14 files**:

- `orfi-kit-cleanup-state.md`
- `orfi-kit-code-review.md`
- `orfi-kit-commit.md`
- `orfi-kit-enforce-guardrails.md`
- `orfi-kit-init.md`
- `orfi-kit-load-state.md`
- `orfi-kit-persist-state.md`
- `orfi-kit-run-codegraph-phase.md`
- `orfi-kit-run-integration-tests-phase.md`
- `orfi-kit-run-unit-tests-phase.md`
- `orfi-kit-set-helper-files-root.md`
- `orfi-kit-standup.md`
- `orfi-kit-sync-branch.md`
- `orfi-kit-sync-master.md`

Companion documentation (repo docs — **NOT installed to the runtime**):

- Per-capability docs live in `docs/skills/` (one `.md` per skill / command / hook / extension),
  not alongside the command files. The sync-branch deeper docs are
  `docs/skills/orfi-kit-sync-branch.md`. The installer copies only the 14 command files into
  `~/.claude/commands/`; it never copies `docs/`.

### 3.2 Claude Code — skills (from `claude-tools/skills/`)

Each is a **directory** holding `SKILL.md` and possibly `README.md` / `evals/`:

- `orfi-kit-git-conventions/`  (contains `SKILL.md`)
- `orfi-kit-guardrails/`  (contains `SKILL.md`)
- `orfi-kit-scrum-poker/`  (contains `SKILL.md`, `evals/`)
- `orfi-kit-xml-docs/`  (contains `SKILL.md`)
- `orfi-kit-doxygen-docs/`  (contains `SKILL.md`)
- `orfi-kit-csharp-code-review/`  (contains `SKILL.md`, `CONFIG.md`) — user-invoked rather than
  auto-triggered; it is a skill directory (not a command file) because it ships the companion
  `CONFIG.md` that a single command file could not carry.
- `orfi-kit-cpp-code-review/`  (contains `SKILL.md`, `CONFIG.md`) — the C++ sibling of the above,
  same rationale for being a skill directory. Runs `clang-format` / `clang-tidy` / build / tests
  instead of the .NET toolchain.

### 3.3 Enforcement hooks (shared scripts, from `claude/hooks/`)

**Seven hook scripts** are the single source of enforcement logic for all four runtimes. Each
runtime registers them through its own channel (Claude `settings.json`, Copilot + Codex native
hooks, OpenCode plugin); the scripts branch on `ORFI_HOOK_PLATFORM` to emit the right output
contract:

- `orfi-kit-enforce-sync.sh` — a **PreToolUse** hook on **Bash** that **blocks `git push`** when a
  feature branch is out of sync with its parent epic. Pairs with `orfi-kit-sync-branch`.
- `orfi-kit-enforce-brevity.sh` — a **Stop** hook that **blocks over-long replies**: it counts the
  lines in the finished assistant turn and, past ~25 (about one page), feeds the reply back with an
  instruction to shorten. Threshold overridable via `ORFI_BREVITY_MAX_LINES`; lifted when the user
  asks for depth. Uses `jq` when present, falls back to `sed` (fails open on a missing tool).
- `orfi-kit-verify-skill-contract.sh` — a **Stop** hook that blocks a skill's final report when a
  step it mandates has no `tool_use` record in the transcript; reads `CONTRACT.conf` beside the
  skill. Disable with `ORFI_SKILL_CONTRACT_OFF=1`.
- `orfi-kit-load-csharp-conventions.sh`, `orfi-kit-load-cpp-conventions.sh` — **PreToolUse**
  loaders that emit the repo's own `.editorconfig` / `.clang-format` / `.clang-tidy` rules (or the
  kit baseline) before a file is written. Advisory.
- `orfi-kit-verify-csharp-format.sh`, `orfi-kit-verify-cpp-format.sh` — **PostToolUse** verifiers
  that run the real formatters after a write and report findings to the model. Advisory.

Registration surfaces: **Claude Code** wires all seven into `~/.claude/settings.json`; **Copilot
CLI** registers five via `copilot/hooks/orfi-kit.json` (native hooks — the two loaders are instead
served by the extension at `onSessionStart`); **OpenCode** runs the same scripts through
`opencode/plugins/orfi-kit-hooks.ts` (no Stop event → brevity and skill-contract are not ported);
**OpenAI Codex** registers five via `codex/hooks.json` (native hooks — the two Stop contracts and
the two loaders are deliberately not wired: Codex's transcript format is not a stable hook
interface and plain stdout is ignored, so unwired beats a guardrail that always passes).

### 3.4 Copilot — skills (from `copilot-tools/skills/`)

**21 skill directories** — full parity with the Claude side. (In Copilot a **skill IS its slash
command**, so the Claude *commands* become Copilot *skills*, giving 7 Claude skills + 14 Claude
commands = 21 Copilot skills.)

- `orfi-kit-cleanup-state/`
- `orfi-kit-code-review/`
- `orfi-kit-commit/`
- `orfi-kit-cpp-code-review/`
- `orfi-kit-csharp-code-review/`
- `orfi-kit-enforce-guardrails/`
- `orfi-kit-git-conventions/`
- `orfi-kit-guardrails/`
- `orfi-kit-init/`
- `orfi-kit-load-state/`
- `orfi-kit-persist-state/`
- `orfi-kit-run-codegraph-phase/`
- `orfi-kit-run-integration-tests-phase/`
- `orfi-kit-run-unit-tests-phase/`
- `orfi-kit-scrum-poker/`
- `orfi-kit-set-helper-files-root/`
- `orfi-kit-standup/`
- `orfi-kit-sync-branch/`
- `orfi-kit-sync-master/`
- `orfi-kit-xml-docs/`
- `orfi-kit-doxygen-docs/`

### 3.5 Copilot — extensions (from `copilot-tools/extensions/`)

- `orfi-kit-guardrails/` — contains `extension.mjs`, a Copilot SDK **session extension** that
  injects guardrails and the C#/C++ conventions as **always-active context** at `onSessionStart`,
  plus an `onUserPromptSubmitted` brevity nudge. It loads context; the **native hooks**
  (`copilot/hooks/orfi-kit.json`, registered to `~/.copilot/hooks/`) add the gating and verifying
  the SDK extension cannot (Stop + PostToolUse events).

### 3.5.1 Copilot — native hooks (from `copilot/hooks/`)

`orfi-kit.json` registers the shared scripts as native Copilot hooks: `PreToolUse`/`Bash` (sync,
deny), `Stop` (brevity + skill-contract, block JSON), `PostToolUse`/`Write|Edit|MultiEdit` (both
verifiers, advisory `additionalContext`). Runs with `ORFI_HOOK_PLATFORM=copilot`, so verdicts are
Copilot JSON, not exit codes. Command-hook timeouts are fail-open.

### 3.5.2 OpenCode — plugin (from `opencode/plugins/`)

`orfi-kit-hooks.ts` runs the same scripts for OpenCode with `ORFI_HOOK_PLATFORM=opencode`:
`tool.execute.before` gates `git push`, `tool.execute.after` merges verifier findings into the tool
result, `chat.system.transform` injects the conventions at chat start (root probe, cached 1h). No
Stop event → brevity and skill-contract are **not** ported (documented gap, not a fake gate).

### 3.5.3 Codex — skills (from `codex/skills/`)

**21 skill directories** — full parity with the Copilot side, adapted from `copilot/skills`. Codex
skills use `name` + `description` frontmatter (unknown keys are ignored), so the Copilot-only fields
(`user-invocable`, `disable-model-invocation`) are dropped. Installed to `~/.agents/skills` (the
Codex user-scope skill home). The two sync skills ship an `agents/openai.yaml` declaring
`policy.allow_implicit_invocation: false`, which preserves the safety intent of Copilot's dropped
`disable-model-invocation` — force-push workflows are never auto-invoked.

### 3.5.4 Codex — global rules + native hooks (from `codex/`)

- `AGENTS.md` — installed to `~/.codex/AGENTS.md`, read first at global scope. Carries the
  always-active guardrails and the write-time C#/C++ conventions **declaratively** — the Codex
  analog of the Copilot extension's `onSessionStart` injection; the two are kept in step.
- `hooks.json` — installed to `~/.codex/hooks.json`. Runs the shared scripts with
  `ORFI_HOOK_PLATFORM=codex`: `PreToolUse`/`^Bash$` (sync — deny JSON under `hookSpecificOutput`),
  `PostToolUse`/`Write|Edit|apply_patch` (both verifiers — advisory `hookSpecificOutput`). **Five of
  seven wired**: the two Stop contracts (brevity, skill-contract) and the two loaders are
  deliberately NOT wired — Codex's transcript format is not a stable hook interface and plain stdout
  is ignored, so wiring them would ship guardrails that always pass. The gap is recorded in the
  file's `description` field, never faked.

### 3.6 EXCLUDE — must NOT be included

> **IMPORTANT — read carefully. Some of these names look like they belong; they do not.**

- **Any XML-docs skill other than `orfi-kit-xml-docs`** — `orfi-kit-xml-docs` is the only
  XML-docs skill that ships. Do **NOT** include any other XML-docs variant.
- **`orfi-gsd-secure-phase.md`** (command) — GSD-specific, out of scope.
- **`orfi-update-gsd-state-phase.md`** (command) — GSD-specific, out of scope.
- **`orfi-scrum-poker-workspace`** — already deleted; was eval scaffolding. Do not resurrect.
- **All `orfi-ae-kit-*` items** (commands and Copilot skills) — these belong to the *other* kit.

---

## 4. Proposed repo layout

```
orfi-kit/
  claude/
    commands/   <- the 14 orfi-kit-*.md command files
    skills/     <- the 7 orfi-kit-* Claude skill dirs
    hooks/      <- the 7 orfi-kit-*.sh shared hook scripts (sync, brevity,
                   skill-contract, 2 convention loaders, 2 format verifiers)
  copilot/
    skills/     <- the 21 orfi-kit-* Copilot skill dirs (Copilot's own copies)
    extensions/ <- orfi-kit-guardrails/  (extension.mjs)
    hooks/      <- orfi-kit.json  (native Copilot hook registration)
  opencode/
    plugins/    <- orfi-kit-hooks.ts  (OpenCode plugin; shells to the same scripts)
  codex/
    skills/     <- the 21 orfi-kit-* Codex skill dirs (adapted from copilot/skills)
    hooks.json  <- native Codex hook registration (installed to ~/.codex/hooks.json)
    AGENTS.md   <- global rules for Codex (installed to ~/.codex/AGENTS.md)
  docs/
    skills/     <- one .md per capability (repo docs; never installed to a runtime)
  scripts/    <- the doc-presence checkers + git-hook wiring, as .ps1/.sh twins:
                 check-xml-docs, check-doxygen-docs, setup-hooks. Installed to the
                 runtime's scripts/ dir as a FALLBACK; a project's own copy wins.
  .githooks/
    pre-commit  <- runs both checkers over STAGED files; blocks the commit on a
                   violation. Wired per clone by setup-hooks (core.hooksPath).
  install.sh
  install.ps1
  README.md
  LICENSE        (MIT)
```

### Why both runtimes live in one repo

- **Single source of truth.** Claude and Copilot variants of the same capability evolve together;
  keeping them in one repo prevents the two surfaces from drifting apart.
- **One install entry point.** A user runs a single `install.sh` / `install.ps1` and picks which
  runtime(s) they want. No second clone, no second installer to keep in sync.

---

## 5. Installer requirements — REPLICATE the trackbed installer

The repo ships **TWO equivalent installers** that are a **maintenance pair kept in sync**:

- `install.sh` — bash
- `install.ps1` — PowerShell (cross-platform `pwsh`: Windows PowerShell 5+, and pwsh on
  Windows / macOS / Linux)

They are **install-time plumbing only**. The kit itself is skills/markdown, seven hook scripts, a
Copilot native-hooks registration, a Codex `hooks.json` + `AGENTS.md`, an OpenCode plugin, and a
Copilot SDK extension — there are **no runtime scripts** beyond the hooks.

> **Reference implementation:** Read the real trackbed installers and adapt them — they implement
> nearly all of the behavior below:
> - `/mnt/BA707A64707A2773/code/trackbed/install.sh`
> - `/mnt/BA707A64707A2773/code/trackbed/install.ps1`
>
> Adapt them: swap the `SKILLS` array, swap the command set (trackbed has one command; orfi-kit has
> fourteen), and **add the genuinely new capabilities** (the seven hooks with three registration
> surfaces, and the Copilot extension) called out below.

### 5.1 Interactive runtime selection

Ask which runtime(s) to install for, accepting **multiple** (space- or comma-separated, e.g.
`1 3` or `1,2,3`):

```
  1) Claude Code
  2) OpenCode
  3) GitHub Copilot CLI
  4) OpenAI Codex CLI
```

### 5.2 Flags

- `--link` / `-Link` — symlink instead of copy (for dev: repo edits go live)
- `--uninstall` / `-Uninstall` — remove an existing install
- `--help` / `-Help` — show usage

### 5.3 The `place()` helper

A helper that copies (or **symlinks** if `--link`) a dir/file from `src → dest`:
creates parent dirs, **replaces** any existing target. (Bash: `place()`; PowerShell: `Place`.)
This is verbatim from trackbed.

### 5.4 The OpenCode conflict rule (CRITICAL)

OpenCode reads **BOTH** `~/.claude/skills` and `~/.config/opencode/skills`. To prevent drift,
skills get **exactly ONE home per machine**:

- **Claude Code only** → `~/.claude/skills/` (+ commands → `~/.claude/commands/`)
- **OpenCode only** → `~/.config/opencode/skills/` (+ commands → `~/.config/opencode/commands/`);
  **BUT** if a Claude install already exists in `~/.claude/skills`, **reuse it** (OpenCode reads it
  natively) rather than duplicating.
- **Both** → `~/.claude/skills/` **only**, and **remove any stale OpenCode-native copy** to prevent
  drift.

### 5.5 Skill sources per runtime

- **Claude Code + OpenCode share the SAME skill source** → `claude/skills` (the 7 Claude skill
  dirs). They also share the OpenCode conflict rule above.
- **Copilot uses its OWN source** → `copilot/skills` (adapted wording, 21 skill dirs) and its own
  home `~/.copilot/skills`. Independent: **no command file** (the skill is its own slash command).
- **Codex uses its OWN source** → `codex/skills` (the 21 Copilot dirs adapted again: `name` +
  `description` frontmatter only, Copilot-only fields dropped) and its own home `~/.agents/skills`
  (the Codex user-scope skill home).

### 5.6 Commands (Claude Code / OpenCode only)

Copy the **14** `orfi-kit-*.md` command files into the runtime's `commands/` dir
(`~/.claude/commands/` and/or `~/.config/opencode/commands/`).

> Make sure your copy loop targets the 14 command files explicitly. Per-capability docs live in
> `docs/skills/` and are never copied to a runtime.

### 5.7 NEW for this kit (not in trackbed) — install the HOOKS, the Copilot native-hooks registration, the Codex hooks.json + AGENTS.md, the OpenCode plugin, and the EXTENSION

This is the **one area where orfi-kit goes beyond trackbed.** Flag it clearly in code comments.

#### 5.7.1 The Bash hook + `settings.json` wiring

1. **Place the hook file:**
   `claude/hooks/orfi-kit-enforce-sync.sh` → `~/.claude/hooks/orfi-kit-enforce-sync.sh`
   (ensure it stays executable: `chmod +x` on bash; on PowerShell the copy preserves content —
   note the file mode is only meaningful on POSIX).

2. **Wire it into `~/.claude/settings.json`** as a **PreToolUse matcher on Bash**. A hook does
   nothing until it is registered. The installer should:
   - **(a)** offer to add the `settings.json` entry **automatically**, merging into the existing
     `PreToolUse` array **idempotently** (do not add a duplicate if an entry already runs this
     hook); **with a fallback to**
   - **(b)** printing clear **manual instructions** if the user declines or if `settings.json` is
     missing/malformed.
   - **Recommended:** do (a) with fallback to (b).

   > **CAUTION — merge, do NOT overwrite.** `~/.claude/settings.json` very likely already contains
   > the user's permissions, env, and other hooks. Read it, parse JSON, **append** to the
   > `hooks.PreToolUse` array (creating the keys if absent), and write it back. Never replace the
   > whole file. Make a backup (`settings.json.bak`) before writing. Use a JSON-aware approach
   > (e.g. `jq` in bash if available, with a careful fallback; `ConvertFrom-Json` /
   > `ConvertTo-Json -Depth 100` in PowerShell).

   **JSON shape to add** (a PreToolUse entry, matcher `"Bash"`, running the hook with a timeout):

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-sync.sh\"",
               "timeout": 10
             }
           ]
         }
       ]
     }
   }
   ```

   Use the **absolute, expanded** path to the installed hook in the `command` string.

3. **Uninstall** should remove the hook file **and** remove the matching `PreToolUse` entry from
   `settings.json` (again, merge-aware: drop only the orfi-kit entry, leave everything else).

   The **same seven scripts** are shared with the Copilot and Codex registrations and the OpenCode
   plugin, so they are installed to `~/.claude/hooks/` whenever any runtime that needs them is
   selected (Claude Code, Copilot CLI, OpenCode, or Codex CLI) — not only for Claude Code.

#### 5.7.1a The Copilot native-hooks registration

When the Copilot runtime is selected, also place `copilot/hooks/orfi-kit.json` → `~/.copilot/hooks/`
(the directory Copilot CLI loads user hook registrations from; it coexists with any other `*.json`,
e.g. `gsd-session.json`). This file registers **five** events from the shared scripts — `PreToolUse`
`Bash` (sync), two `PostToolUse` `Write|Edit|MultiEdit` (verifiers), two `Stop` (brevity +
skill-contract) — each with `env.ORFI_HOOK_PLATFORM=copilot` and a `timeoutSec` matching Claude Code.
The two **loaders are deliberately not registered**: the extension serves conventions at
`onSessionStart`. Uninstall removes the file.

#### 5.7.1b The OpenCode plugin

When the OpenCode runtime is selected, also place `opencode/plugins/orfi-kit-hooks.ts` →
`~/.config/opencode/plugins/`. The plugin shells out to the shared scripts with
`ORFI_HOOK_PLATFORM=opencode`: `tool.execute.before` gates `git push`, `tool.execute.after` merges
verifier findings into the tool result, `chat.system.transform` injects conventions at chat start.
OpenCode has **no Stop event**, so brevity and skill-contract are not ported — document that gap in
the plugin header rather than faking a gate. Uninstall removes the file.

#### 5.7.1c The Codex hooks.json + AGENTS.md

When the Codex runtime is selected, also place `codex/hooks.json` → `~/.codex/hooks.json` and
`codex/AGENTS.md` → `~/.codex/AGENTS.md` (both read first, global scope). They coexist with any
other `hooks.json` / `AGENTS.md` in that directory by **merging**: append the orfi-kit
`PreToolUse`/`PostToolUse` handlers without dropping existing ones, and append the orfi-kit blocks
to `AGENTS.md`. The file registers the **same five** events from the shared scripts as the Copilot
registration — `PreToolUse`/`^Bash$` (sync, deny) and `PostToolUse`/`Write|Edit|apply_patch`
(both verifiers, advisory) — each command prefixed with `ORFI_HOOK_PLATFORM=codex` inline (Codex
hook handlers accept no `env` field), with a `timeout` matching Claude Code. The two **Stop
contracts and the two loaders are deliberately not wired**: Codex's transcript format is not a
stable hook interface and plain stdout is ignored — record that gap in the hooks.json `description`
field, never fake a gate. Codex skills install to `~/.agents/skills`. Git Bash is required on
Windows (commands run through the shell). Uninstall removes `~/.codex/hooks.json`,
`~/.codex/AGENTS.md`, and the Codex skill dirs.

#### 5.7.2 The Copilot extension

- When the Copilot runtime is selected, also install the extension:
  `copilot/extensions/orfi-kit-guardrails/` (contains `extension.mjs`) → Copilot's **extensions
  location**. The extension loads guardrails + conventions at `onSessionStart` and nudges on
  over-long previous replies; the native hooks (§5.7.1a) provide the Stop and PostToolUse events the
  SDK extension cannot.
- **VERIFY THE CORRECT PATH.** The extensions directory is the analog of `~/.copilot/skills` for
  extensions, but confirm the actual Copilot CLI extensions path before hardcoding it (check
  Copilot CLI docs / an existing install). Do not guess silently — if unsure, document the assumed
  path in a code comment and in the README so the user can correct it.

### 5.8 Final message

Print a **"Done"** message listing what was installed (per runtime) and an **example invocation**,
e.g. `/orfi-kit-commit` or `/orfi-kit-code-review`.

### 5.9 The SKILLS array

The array the installer iterates over is the **21 `orfi-kit-*` skill names** (§3.4). Note that the
Claude side ships only 7 of these as *skills* and the other 14 as *commands* — structure the
installer so the Claude path installs 7 skills + 14 commands, while the Copilot path installs all
21 as skills. Keep a `SKILLS` array for the Copilot/Claude-skills overlap and a separate `COMMANDS`
array for the 14 Claude command files.

---

## 6. README requirements

The repo `README.md` must:

- Explain **what orfi-kit is** (and note orfi-ae-kit is a separate kit that depends on it).
- **List each skill / command / hook** with a one-line description:
  - `orfi-kit-git-conventions` — commit / branch / PR naming format.
  - `orfi-kit-guardrails` — always-active behavioral constraints (honesty, safe VCS, clarity).
  - `orfi-kit-enforce-guardrails` — re-assert guardrails when behavior drifts.
  - `orfi-kit-commit` — assemble and write a conventional commit.
  - `orfi-kit-code-review` — structured review of the current diff.
  - `orfi-kit-load-state` / `orfi-kit-persist-state` — load / save session context.
  - `orfi-kit-run-unit-tests-phase` / `orfi-kit-run-integration-tests-phase` /
    `orfi-kit-run-codegraph-phase` — run the respective test phase.
  - `orfi-kit-scrum-poker` — Fibonacci estimate a Jira ticket via Atlassian MCP.
  - `orfi-kit-xml-docs` — enforce C# XML documentation.
  - `orfi-kit-sync-branch` / `orfi-kit-sync-master` — keep a branch synced with its parent.
  - `orfi-kit-enforce-sync.sh` (hook) — PreToolUse/Bash hook that blocks `git push` on an
    out-of-sync feature branch.
- Document the **install command and flags in BOTH forms**:
  - bash: `./install.sh`, `./install.sh --link`, `./install.sh --uninstall`, `./install.sh --help`
  - PowerShell: `./install.ps1`, `./install.ps1 -Link`, `./install.ps1 -Uninstall`,
    `./install.ps1 -Help`
- Document the **uninstall** for both.
- Note that the **sync-branch feature's deeper docs** live in
  `docs/skills/orfi-kit-sync-branch.md` (per-capability docs live under `docs/skills/`).
- Mention the **settings.json hook wiring** (auto vs manual), the **Copilot extension** install,
  and the **Codex hooks.json / AGENTS.md / `~/.agents/skills`** install.

---

## 7. Acceptance checklist

The implementer can verify completion against this list:

- [ ] **All skills present on all runtimes** — `claude/skills` has the 7 Claude skill dirs;
      `copilot/skills` has all 21 Copilot skill dirs; `codex/skills` has all 21 Codex skill dirs
      (frontmatter reduced to `name` + `description`; the sync skills carry `agents/openai.yaml`
      with `policy.allow_implicit_invocation: false`). `orfi-kit-csharp-code-review` ships its
      companion `CONFIG.md` alongside `SKILL.md` in all of them.
- [ ] **14 Claude command files** present in `claude/commands/`. Per-capability docs live in
      `docs/skills/` (one `.md` per capability) and are never installed to a runtime.
- [ ] **`orfi-kit-csharp-code-review` behaves as specified** — it is a *skill directory* rather than a
      command file specifically so it can ship `CONFIG.md`; verify that companion file installs
      alongside `SKILL.md` in copy **and** `--link` mode, and is removed on uninstall. The skill must
      (a) declare `Bash` in `allowed-tools` — a read-only reviewer cannot run the enforcers, which is
      the failure it exists to prevent; (b) use `dotnet format --verify-no-changes` only, never bare
      `dotnet format`, since a review must not rewrite the code under review; (c) ground every style
      verdict in the repo's own config via the authority ladder, treating the bundled `CONFIG.md`
      baseline as a seed to adopt and never as authority to flag against a repo that has its own;
      (d) resolve intent through the source-of-truth ladder, degrade to "completeness unverifiable"
      when no rung is available, and never block or refuse because a document was absent; and
      (e) depend on no other kit — plan discovery comes from this kit's own files or from the user.
- [ ] **`orfi-kit-cpp-code-review` behaves as specified** — same shape as its C# sibling, with the
      C++ toolchain: `clang-format --dry-run -Werror` (never `-i`), `clang-tidy` (only meaningful
      with a `compile_commands.json` — it must **not** reconfigure the build to create one), then the
      project's own build and test commands. It must (a) exclude vendored and generated code and say
      which paths it skipped; (b) treat missing `.clang-format` / `.clang-tidy` as the *normal* case,
      falling back to the prevailing pattern of the file being changed rather than general C++ norms;
      and (c) cover the C++-specific judgment lanes — memory/lifetime, const correctness, and header
      hygiene.
- [ ] **Hooks present** — all seven `claude/hooks/orfi-kit-*.sh` in the repo (sync, brevity,
      skill-contract, the two convention loaders, the two format verifiers); all install to
      `~/.claude/hooks/`; all remain executable.
- [ ] **Hook registration surfaces** — Claude (`settings.json` entries), Copilot
      (`~/.copilot/hooks/orfi-kit.json` registers PreToolUse/PostToolUse/Stop events from the shared
      scripts), OpenCode (`~/.config/opencode/plugins/orfi-kit-hooks.ts` plugin), and Codex
      (`~/.codex/hooks.json` registers PreToolUse/PostToolUse from the shared scripts; the two Stop
      contracts + two loaders recorded in the `description` field as deliberately unwired) all
      wired; uninstall removes each surface.
- [ ] **Hook settings wiring** — installer adds the PreToolUse/Bash entry (sync) and the Stop entry
      (brevity, no `matcher` — Stop events are not tool-scoped) to `settings.json` idempotently
      (auto), with manual-instructions fallback for each; uninstall removes both; `settings.json`
      is **merged, never overwritten**, and backed up before write.
- [ ] **Copilot extension** present (`copilot/extensions/orfi-kit-guardrails/extension.mjs`) and
      installed to the verified Copilot extensions path.
- [ ] **Doc-checker scripts ship and install** — `scripts/` holds three `.ps1`/`.sh` twin pairs
      (`check-xml-docs`, `check-doxygen-docs`, `setup-hooks`), all six install to the selected
      runtime's `scripts/` dir, and uninstall removes them — deleting the directory **only** when
      uninstall emptied it, never one holding the user's own scripts. Every `.sh` is committed
      `100755`: a `100644` hook is one git silently refuses to run on POSIX, which reads as a
      guardrail that passes.
- [ ] **The checker resolution ladder is a fallback, not an override** — the review skills call the
      checkers by the *relative* path `scripts/check-…`, so the reviewed repo's own copy wins and the
      installed copy applies only when that repo has none. The installer never writes into a user's
      project.
- [ ] **`.githooks/pre-commit` present and enforcing** — runs both checkers over the **staged** files
      and exits non-zero on a violation. `--staged` is correct there because the index *is* the
      scope; the review skills use `--files` against the branch diff instead, since `--changed`
      resolves to uncommitted work and at review time exits 0 having inspected nothing. When a
      checker is absent the hook says so on stderr rather than passing quietly.
- [ ] **Re-install is an update, and its limits are documented** — files are replaced wholesale so
      the repo stays the source of truth; `settings.json` merges without duplicating. Because the
      installer writes its current arrays rather than diffing a manifest, a **renamed or dropped**
      item leaves a stale copy behind; README says so and points at uninstall-then-install.
- [ ] **Installer runs interactively**, handles **all runtime combos** (1 / 2 / 3 / 4 and any
      combination), and the **OpenCode conflict rule** behaves correctly (single skill home; both →
      `~/.claude/skills` + stale OpenCode copy removed; OpenCode-only reuses an existing Claude
      install).
- [ ] **`--link` / `--uninstall` / `--help`** (and PowerShell `-Link` / `-Uninstall` / `-Help`)
      all work.
- [ ] **Everything is `orfi-kit`-scoped** — every shipped item is prefixed `orfi-kit-`, and there
      are no stray names to exclude: no `orfi-ae-kit-*`, no `orfi-gsd-secure-phase`, no
      `orfi-update-gsd-state-phase`, no `orfi-scrum-poker-workspace`.
- [ ] **README complete** — what-it-is, per-item descriptions, install/uninstall in both bash and
      PowerShell forms, sync-branch docs pointer, hook + extension notes.
- [ ] **`install.sh` and `install.ps1` are behaviorally equivalent** (the maintenance pair is in
      sync).
- [ ] **LICENSE** (MIT) present.

---

## 8. Future work

Ideas deliberately deferred. None of these is required for the kit to be complete; each is recorded
so the reasoning isn't lost.

### 8.1 A conventions switch, resolved the same way ownership is

`orfi-kit-cpp-code-review` resolves the **memory ownership style** per project rather than assuming
one, because the answer varies by team, company, domain, and era. The resolution order is:

1. The repo's own encoded config (`.clang-tidy` enabling `cppcoreguidelines-owning-memory`)
2. A written project or org convention (ADR, coding standards, `ONBOARDING.md`, `CLAUDE.md`)
3. An explicit argument (`RAW` / `SMART`)
4. The prevailing pattern in the file being changed
5. Asking the user

**The same mechanism should generalize to naming and formatting conventions.** Today `CONFIG.md`
ships one baseline — `m_`/`s_` prefixes, `camelBack` methods, `UPPER_CASE` constants, Allman braces —
drawn from the reference Qt projects (these are the conventions those projects actually use), and
explicitly framed as one team's choices rather than C++ law.
But a repo following Google, LLVM, Qt house style, or a company standard has a different, equally
valid answer, and right now the skill can only fall back to "prevailing pattern" for it.

A future `CONVENTIONS` switch would let a caller name the style set and slot into the identical ladder:
repo config wins, then a written convention, then the explicit argument, then prevailing pattern, then
ask.

**Shape this would likely take:** `CONFIG.md` currently holds a single baseline — the house style, and
the default. Rather than parameterising that one file, ship a `configs/` directory beside `SKILL.md`
with one file per style set (`house.md`, `google.md`, `llvm.md`, …), keeping the house style as the
default when no switch is given. The skill selects one; everything else about the ladder is unchanged.
That keeps each style set readable on its own and avoids a single file trying to describe several
mutually exclusive conventions at once. Note the installer copies whole skill directories, so a
`configs/` subdirectory ships automatically with no installer change. The design constraint that makes the ownership
switch safe applies here too — **the switch must only decide whether a *stylistic* difference is
reportable; genuine defects stay findings in every mode.** For ownership that means leaks and
use-after-free are always flagged; the naming equivalent is that a misleading or shadowing identifier
is a real problem regardless of which case convention is in force.

Worth doing the same for the C# sibling if it lands, though the need is weaker there: `.editorconfig`
is near-universal in C#, so rung 1 is usually populated and the guessing problem barely arises. In
C++ rung 1 is usually empty, which is exactly why the ladder matters more.

### 8.2 Run both review skills against real code

Neither `orfi-kit-csharp-code-review` nor `orfi-kit-cpp-code-review` has been executed against an
actual diff. Both are verified **structurally** — install/uninstall in copy and `--link` mode,
`CONFIG.md` shipping alongside `SKILL.md`, installer arrays resolving, per-runtime divergence limited
to the intended differences — but their *behavior* is unproven.

Two consequences to settle when that happens:

- The **Example** section in each `docs/skills/` page is hand-written to show the report shape. Replace
  it with genuine captured output.
- The C++ tool lane assumes `clang-format` / `clang-tidy` / `compile_commands.json` may all be absent
  and degrades accordingly. That degradation path is the *common* case in the reference projects, so it
  is the first thing worth exercising — not the happy path.

---

*End of orfi-kit PRD.*
