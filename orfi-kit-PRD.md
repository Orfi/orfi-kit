# orfi-kit — PRD / Onboarding Build Guide

> **Audience:** A future Claude Code session with **no prior context**. This document is the
> complete, self-contained spec for assembling the **orfi-kit** repository from existing source
> files and building its installer. Read it top to bottom before acting.

---

## 1. Purpose

**orfi-kit** is a generic, reusable bundle of **Claude Code + GitHub Copilot CLI** skills,
commands, and hooks for AI-augmented development. It packages a team's day-to-day automation:

- **git conventions** — commit message / branch / PR naming format
- **guardrails** — foundational behavioral constraints (honesty, safe VCS, clear comms)
- **commit** — assemble and write a conventional commit
- **code review** — structured review of a diff
- **session state** — persist / load working context across sessions
- **test runners** — unit, integration, and codegraph phase test commands
- **scrum-poker** — Fibonacci planning-poker estimation of Jira tickets (via Atlassian MCP)
- **C# XML-doc enforcement** — XML documentation rules
- **C++ Doxygen-doc enforcement** — header-only Doxygen documentation rules (+ check script)
- **branch sync** — keep a feature branch in sync with its parent epic, enforced by a push hook

It is **one of two kits**:

| Kit | What it is | Relationship |
|---|---|---|
| **orfi-kit** (this PRD) | The generic, reusable kit. | Standalone. |
| **orfi-ae-kit** | The Architect/Executor pattern (a separate kit). | A **SEPARATE repo** that lists orfi-kit as a **prerequisite**. |

**This PRD is ONLY for orfi-kit.** Do not pull any `orfi-ae-kit-*` items into this repo.

### Naming scheme

Every item is prefixed **`orfi-kit-`**. Everything installs **flat** (no nesting), so invocation
is uniform across the kit — e.g. `/orfi-kit-commit`, `/orfi-kit-code-review`,
`/orfi-kit-scrum-poker`.

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

### 3.3 Claude Code — hooks (from `claude-tools/hooks/`)

- `orfi-kit-enforce-sync.sh` — a **PreToolUse** hook on **Bash** that **blocks `git push`** when a
  feature branch is out of sync with its parent epic. Pairs with `orfi-kit-sync-branch`.

### 3.4 Copilot — skills (from `copilot-tools/skills/`)

**19 skill directories** — full parity with the Claude side. (In Copilot a **skill IS its slash
command**, so the Claude *commands* become Copilot *skills*, giving 5 Claude skills + 14 Claude
commands = 19 Copilot skills.)

- `orfi-kit-cleanup-state/`
- `orfi-kit-code-review/`
- `orfi-kit-commit/`
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
  injects guardrails as **always-active context**.

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
    skills/     <- the 5 orfi-kit-* Claude skill dirs
    hooks/      <- orfi-kit-enforce-sync.sh
  copilot/
    skills/     <- the 19 orfi-kit-* Copilot skill dirs (Copilot's own copies)
    extensions/ <- orfi-kit-guardrails/  (extension.mjs)
  docs/
    skills/     <- one .md per capability (repo docs; never installed to a runtime)
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

They are **install-time plumbing only**. The kit itself is skills/markdown (and one hook + one
extension) — there are **no runtime scripts** beyond the hook.

> **Reference implementation:** Read the real trackbed installers and adapt them — they implement
> nearly all of the behavior below:
> - `/mnt/BA707A64707A2773/code/trackbed/install.sh`
> - `/mnt/BA707A64707A2773/code/trackbed/install.ps1`
>
> Adapt them: swap the `SKILLS` array, swap the command set (trackbed has one command; orfi-kit has
> fourteen), and **add the two genuinely new capabilities** (hook + extension) called out below.

### 5.1 Interactive runtime selection

Ask which runtime(s) to install for, accepting **multiple** (space- or comma-separated, e.g.
`1 3` or `1,2,3`):

```
  1) Claude Code
  2) OpenCode
  3) GitHub Copilot CLI
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

- **Claude Code + OpenCode share the SAME skill source** → `claude/skills` (the 5 Claude skill
  dirs). They also share the OpenCode conflict rule above.
- **Copilot uses its OWN source** → `copilot/skills` (adapted wording, 19 skill dirs) and its own
  home `~/.copilot/skills`. Independent: **no command file** (the skill is its own slash command).

### 5.6 Commands (Claude Code / OpenCode only)

Copy the **14** `orfi-kit-*.md` command files into the runtime's `commands/` dir
(`~/.claude/commands/` and/or `~/.config/opencode/commands/`).

> Make sure your copy loop targets the 14 command files explicitly. Per-capability docs live in
> `docs/skills/` and are never copied to a runtime.

### 5.7 NEW for this kit (not in trackbed) — install the HOOK and the EXTENSION

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

#### 5.7.2 The Copilot extension

- When the Copilot runtime is selected, also install the extension:
  `copilot/extensions/orfi-kit-guardrails/` (contains `extension.mjs`) → Copilot's **extensions
  location**.
- **VERIFY THE CORRECT PATH.** The extensions directory is the analog of `~/.copilot/skills` for
  extensions, but confirm the actual Copilot CLI extensions path before hardcoding it (check
  Copilot CLI docs / an existing install). Do not guess silently — if unsure, document the assumed
  path in a code comment and in the README so the user can correct it.

### 5.8 Final message

Print a **"Done"** message listing what was installed (per runtime) and an **example invocation**,
e.g. `/orfi-kit-commit` or `/orfi-kit-code-review`.

### 5.9 The SKILLS array

The array the installer iterates over is the **19 `orfi-kit-*` skill names** (§3.4). Note that the
Claude side ships only 5 of these as *skills* and the other 14 as *commands* — structure the
installer so the Claude path installs 5 skills + 14 commands, while the Copilot path installs all
19 as skills. (Trackbed used one shared array because its command set was trivial; here keep a
`SKILLS` array for the Copilot/Claude-skills overlap and a separate `COMMANDS` array for the 14
Claude command files.)

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
- Mention the **settings.json hook wiring** (auto vs manual) and the **Copilot extension** install.

---

## 7. Acceptance checklist

The implementer can verify completion against this list:

- [ ] **All skills present on both runtimes** — `claude/skills` has the 5 Claude skill dirs;
      `copilot/skills` has all 19 Copilot skill dirs.
- [ ] **14 Claude command files** present in `claude/commands/`. Per-capability docs live in
      `docs/skills/` (one `.md` per capability) and are never installed to a runtime.
- [ ] **Hook present** — `claude/hooks/orfi-kit-enforce-sync.sh` in the repo; installs to
      `~/.claude/hooks/`; remains executable.
- [ ] **Hook settings wiring** — installer adds the PreToolUse/Bash entry to `settings.json`
      idempotently (auto), with manual-instructions fallback; uninstall removes it; `settings.json`
      is **merged, never overwritten**, and backed up before write.
- [ ] **Copilot extension** present (`copilot/extensions/orfi-kit-guardrails/extension.mjs`) and
      installed to the verified Copilot extensions path.
- [ ] **Installer runs interactively**, handles **all runtime combos** (1 / 2 / 3 and any
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

*End of orfi-kit PRD.*
