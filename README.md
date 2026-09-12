![orfi-kit](assets/header.png)

# orfi-kit

A generic, reusable bundle of **Claude Code, OpenCode, GitHub Copilot CLI, and OpenAI Codex CLI**
skills, commands, and hooks for AI-augmented development. It packages a team's day-to-day automation —
git conventions, a push/brevity/contract enforcement layer, commits, code review, session state, test
runners, Jira estimation, C# XML-doc and C++ Doxygen-doc rules, and branch sync — and installs them
flat (every item is prefixed `orfi-kit-`).

> **Related kit:** `orfi-ae-kit` (the Architect/Executor pattern) is a **separate** repo that lists
> orfi-kit as a prerequisite. This repo is only orfi-kit.

## What's inside

Every row below links to a full doc page under [`docs/skills/`](docs/skills/).

### Skills (always-on, auto-triggered, or invoked)

Claude Code / OpenCode skills (Copilot ships these as slash commands; Codex invokes them by bare
name). Most trigger on their own; the two code-review skills (`orfi-kit-csharp-code-review`,
`orfi-kit-cpp-code-review`) are skill directories because each ships a companion `CONFIG.md`, but you
invoke them like commands.

| Capability | What it does | Trigger | Requires |
| --- | --- | --- | --- |
| [orfi-kit-guardrails](docs/skills/orfi-kit-guardrails.md) | Always-on behavioral constraints enforcing honesty, real test verification, safe version control, and clear communication. | Always active (not user-invocable) | — |
| [orfi-kit-git-conventions](docs/skills/orfi-kit-git-conventions.md) | Required commit / branch / PR formats (typed verbs, optional ticket IDs) plus the epic/story branching + master→epic→feature sync workflow. | Auto-triggers on any git commit / branch / PR operation | A ticket ID when one exists; for epic work: an `origin` remote and `epic/*` + `feature/*` branches |
| [orfi-kit-scrum-poker](docs/skills/orfi-kit-scrum-poker.md) | Estimates a Jira ticket on the Fibonacci scale (1/2/3/5/8/?) with calibration and reasoning, then writes the points back after you confirm. | Auto-triggers when you ask to estimate / size a Jira ticket | Atlassian MCP server with access to your Jira instance |
| [orfi-kit-xml-docs](docs/skills/orfi-kit-xml-docs.md) | Enforces formal `///` XML doc comments on every public, protected, and static C# member. | Auto-triggers when writing / editing C# XML doc comments | A C# project; `pwsh` for the checker |
| [orfi-kit-doxygen-docs](docs/skills/orfi-kit-doxygen-docs.md) | Enforces Doxygen comments on every exposed (public / protected / static) declaration in C++ headers; follows the file's existing `/**` or `///` style. | Auto-triggers when writing / editing C++ Doxygen comments | A C++ project; `pwsh` or bash for the checker |
| [orfi-kit-csharp-code-review](docs/skills/orfi-kit-csharp-code-review.md) | C# review that **runs** the enforcers (`dotnet format --verify-no-changes`, `build`, `test`) and grounds every style verdict in the repo's own `.editorconfig` / `Directory.Build.props` rather than general C# norms, then judges correctness, completeness, and ADR/PRD conformance. Ships a `CONFIG.md` baseline for repos with no config. | `/orfi-kit-csharp-code-review [DIFF\|FULL\|BUGS\|SECURITY\|PERFORMANCE\|<path>]` — diff-scoped, all lanes by default | A C# project and the .NET SDK; an upstream branch for diff scope |
| [orfi-kit-cpp-code-review](docs/skills/orfi-kit-cpp-code-review.md) | C++ sibling of the above: **runs** `clang-format --dry-run`, `clang-tidy`, the project's build and tests, and grounds style verdicts in the repo's own `.clang-format` / `.clang-tidy` — or, when those are absent (the common case in C++), in the prevailing pattern of the file being changed. Adds memory/lifetime, const-correctness, and header-hygiene judgment; skips vendored and generated code. Ships a `CONFIG.md` baseline. | `/orfi-kit-cpp-code-review [DIFF\|FULL\|RAW\|SMART\|BUGS\|SECURITY\|PERFORMANCE\|<path>]` — diff-scoped, all lanes by default; ownership style (raw vs smart pointers) is resolved per project from config, conventions, or by asking | A C++ project; `clang-format` / `clang-tidy` + a compilation database for the tool lane (degrades without them) |

### Commands (you invoke them)

Claude Code / OpenCode commands — also available as Copilot slash commands.

| Capability | What it does | Invoke | Requires |
| --- | --- | --- | --- |
| [orfi-kit-commit](docs/skills/orfi-kit-commit.md) | Commit current changes with messages auto-formatted to orfi-kit's git conventions. | `/orfi-kit-commit` | A ticket ID if one applies (you're prompted; omitted if none) |
| [orfi-kit-code-review](docs/skills/orfi-kit-code-review.md) | Read-only, file-by-file review of the codebase, optionally scoped to BUGS / SECURITY / PERFORMANCE. | `/orfi-kit-code-review` | — |
| [orfi-kit-standup](docs/skills/orfi-kit-standup.md) | Builds a Teams-ready status/standup report (In progress / Done / Next / Blockers) through guided questions, fetching Jira titles for any ticket you name, then iterates until you confirm. | `/orfi-kit-standup` | Atlassian MCP server only if you want ticket titles fetched automatically (else you're prompted) |
| [orfi-kit-enforce-guardrails](docs/skills/orfi-kit-enforce-guardrails.md) | Re-asserts all operational guardrails to snap behavior back into compliance when it drifts. | `/orfi-kit-enforce-guardrails` | — |
| [orfi-kit-set-helper-files-root](docs/skills/orfi-kit-set-helper-files-root.md) | Configures (creates or changes) the per-repo helper-files root the state files live under, recorded in an untracked `.orfi-kits/helper-files-root` pointer. | `/orfi-kit-set-helper-files-root` | A path to your helper-files root (prompted if omitted) |
| [orfi-kit-init](docs/skills/orfi-kit-init.md) | Bootstraps the kit files (session-state + onboarding placeholders) under `<root>\orfi-kits\` — create-if-absent, never overwrites; quits if already initialized. | `/orfi-kit-init` | The helper-files root (configured on the spot if unset) |
| [orfi-kit-cleanup-state](docs/skills/orfi-kit-cleanup-state.md) | Strips internal scaffolding (`.orfi-kits/`, `.planning/`, `.trackbed/`, `docs/superpowers/`) before the final epic PR merge — backs up to `helper_files/stripped/` first, then `git rm`. Destructive; `☠️` confirmation prompt. | `/orfi-kit-cleanup-state` | Run on the branch being finalized |
| [orfi-kit-load-state](docs/skills/orfi-kit-load-state.md) | Restores a prior session by reading its `CLAUDE-SESSION-STATE.md` handoff before any other work. | `/orfi-kit-load-state` | The helper-files root configured (see above); a `CLAUDE-SESSION-STATE.md` written by a prior session |
| [orfi-kit-persist-state](docs/skills/orfi-kit-persist-state.md) | Writes a session handoff file so you can clear context and resume work later. | `/orfi-kit-persist-state` | The helper-files root configured (see above) |
| [orfi-kit-run-unit-tests-phase](docs/skills/orfi-kit-run-unit-tests-phase.md) | Runs unit tests for one GSD phase (or all), logging parsed pass/fail/skip summaries. | `/orfi-kit-run-unit-tests-phase` | A .NET project using `dotnet test` |
| [orfi-kit-run-integration-tests-phase](docs/skills/orfi-kit-run-integration-tests-phase.md) | Runs integration tests for one GSD phase (or all), logging parsed pass/fail/skip summaries. | `/orfi-kit-run-integration-tests-phase` | A .NET project; repo root for a `.tests/` dir |
| [orfi-kit-run-codegraph-phase](docs/skills/orfi-kit-run-codegraph-phase.md) | Runs codegraph for a single GSD phase, identified by a phase-number argument. | `/orfi-kit-run-codegraph-phase` | — |
| [orfi-kit-sync-branch](docs/skills/orfi-kit-sync-branch.md) | Syncs an epic-derived working branch (any prefix) through `origin/master → epic/* → working branch` before push, auto-detecting merge vs rebase. | `/orfi-kit-sync-branch` | An epic-derived working branch (any prefix, not `master`/`epic/*`); `origin` remote; `epic/*` naming |
| [orfi-kit-sync-master](docs/skills/orfi-kit-sync-master.md) | Rebases the current branch on `origin/master`, resolves conflicts, and force-pushes with `--force-with-lease` for linear history. Aborts on `master`/`epic/*` and steers epic-derived branches to `/orfi-kit-sync-branch`. | `/orfi-kit-sync-master` | A standalone branch (no epic parent); an `origin/master`; a remote tracking branch |

### Hooks & extensions (passive)

One set of **seven hook scripts** is the single source of logic; each runtime registers them through
its own channel. Claude Code via `~/.claude/settings.json`, Copilot CLI via native hooks
(`~/.copilot/hooks/orfi-kit.json` — [orfi-kit-copilot-hooks](docs/skills/orfi-kit-copilot-hooks.md)),
OpenCode via a plugin (`~/.config/opencode/plugins/orfi-kit-hooks.ts` —
[orfi-kit-opencode-plugin](docs/skills/orfi-kit-opencode-plugin.md)), and Codex CLI via native hooks
(`~/.codex/hooks.json` — [orfi-kit-codex-hooks](docs/skills/orfi-kit-codex-hooks.md)). The scripts
branch on `ORFI_HOOK_PLATFORM` to speak each runtime's output contract instead of each platform
re-implementing the logic. Surface below means: **Claude** (settings.json hooks), **Copilot** (native
hooks / extension), **OpenCode** (plugin), **Codex** (native hooks / global rules).

| Capability | What it does | Surface | Requires |
| --- | --- | --- | --- |
| [orfi-kit-enforce-sync-hook](docs/skills/orfi-kit-enforce-sync-hook.md) | PreToolUse/Bash hook that **blocks `git push`** from an epic-derived working branch (any prefix) until it's rebased on its parent `epic/*`; ignores `master`/`epic/*`. Pairs with `orfi-kit-sync-branch`. | Claude · Copilot · OpenCode (block) | An epic-derived working branch; `origin` remote; at least one `origin/epic/*` branch (else push is allowed) |
| [orfi-kit-enforce-brevity-hook](docs/skills/orfi-kit-enforce-brevity-hook.md) | Stop hook that **blocks over-long replies**: counts lines in the assistant's finished reply and, if over ~25 (about one page), feeds it back with an instruction to shorten. Lifts the limit when the user asks for depth (e.g. "in full", "in detail", "elaborate"). Enforces the guardrails' brevity rule mechanically. | Claude · Copilot (block); **not OpenCode** — no Stop event | A Stop-hook-capable runtime. Uses `jq` when present, falls back to `sed`, so no external tool is required |
| [orfi-kit-load-csharp-conventions-hook](docs/skills/orfi-kit-load-csharp-conventions-hook.md) | PreToolUse hook that **loads the repo's own C# rules before a `.cs` file is written**: the nearest `.editorconfig` `[*.cs]` section (nearest-file-wins to `root = true`), the `dotnet_naming_rule`/`_symbols`/`_style` families regrouped as complete triplets, and `TreatWarningsAsErrors` / `EnforceCodeStyleInBuild` / `Nullable` from `Directory.Build.props`. States that `applicable_kinds = field` covers `const` and `static readonly`. **When the repo encodes nothing, falls back to the kit's own baseline from the code-review skill's `CONFIG.md` and enforces that as the contract** — repo config still wins whenever it exists. Read-only; never writes config into your repo. | Claude (PreToolUse) · Copilot (extension at `onSessionStart`) · OpenCode (chat start) | Nothing — uses `jq` when present, falls back to `sed`. Reports plainly when the repo encodes no rules |
| [orfi-kit-load-cpp-conventions-hook](docs/skills/orfi-kit-load-cpp-conventions-hook.md) | PreToolUse hook that **loads the repo's own C++ rules before a source/header is written**: the nearest `.clang-format` and `.clang-tidy` `readability-identifier-naming.*` keys (paired with their values). Detects whether `compile_commands.json` exists and says so when `clang-tidy` would be inert without it. Treats "no config at all" as the normal C++ case and **falls back to the kit's own baseline from the code-review skill's `CONFIG.md`, enforced as the contract** — repo config still wins whenever it exists. Read-only; never proposes bulk renames. | Claude (PreToolUse) · Copilot (extension at `onSessionStart`) · OpenCode (chat start) | Nothing — uses `jq` when present, falls back to `sed` |
| [orfi-kit-verify-csharp-format-hook](docs/skills/orfi-kit-verify-csharp-format-hook.md) | PostToolUse hook that runs `dotnet format --verify-no-changes` scoped to the edited file right **after** it is written, reporting violations with file/line/column. Findings are delivered to the model (Claude `additionalContext`, Copilot `additionalContext`, OpenCode merged tool output) plus a copy on stderr — not just printed to a transcript nobody reads. Advisory by default (`ORFI_CSHARP_FORMAT_BLOCKING=1` to block; the other platforms have no block channel). | Claude · Copilot · OpenCode (advisory) | The .NET SDK and a `.csproj` above the file — says so on stderr and exits 0 when either is missing, never a silent pass |
| [orfi-kit-verify-cpp-format-hook](docs/skills/orfi-kit-verify-cpp-format-hook.md) | PostToolUse hook that runs `clang-format --dry-run --Werror` after a C/C++ write, plus `clang-tidy` **only** when a `compile_commands.json` exists — otherwise it reports that naming is unverified rather than clean. Findings delivered to the model (Claude `additionalContext`, Copilot `additionalContext`, OpenCode merged tool output) plus a copy on stderr. Advisory by default. | Claude · Copilot · OpenCode (advisory) | `clang-format` / `clang-tidy` and a compilation database for the naming half; every absence is reported on stderr |
| [orfi-kit-verify-skill-contract-hook](docs/skills/orfi-kit-verify-skill-contract-hook.md) | Stop hook that **blocks a skill's final report when a mandated step has no `tool_use` record** in the session transcript. Reads a `CONTRACT.conf` beside the skill's `SKILL.md` (shipped for both code-review skills: companion skills, tool lane, scope diff, and the `--changed` / `@{u}` / `clang-format -i` traps). Fires only when a contract is open *and* the reply is report-shaped, so mid-review turns are untouched. Satisfied by the **attempt**, not the exit code — an unavailable tool still leaves a record, so `skipped (unavailable)` stays honest after trying rather than instead of trying. Distinguishes a step never run from one the report *claims* ran. No conversational escape hatch by design; `ORFI_SKILL_CONTRACT_OFF=1` disables it. | Claude · Copilot (block); **not OpenCode** — no Stop event | A Stop-hook-capable runtime. Uses `jq` when present, falls back to `grep`/`sed`. Verifies the transcript is Claude-shaped before enforcing (honesty guard) |
| [orfi-kit-guardrails-extension](docs/skills/orfi-kit-guardrails-extension.md) | Copilot SDK session extension that injects the guardrails as always-active context, the C#/C++ coding conventions — scoped to the languages actually present in the workspace — and an `onUserPromptSubmitted` brevity nudge as fallback. Native Copilot hooks (above) do the blocking; the extension loads the context. Installs to `~/.copilot/extensions/orfi-kit-guardrails/`. | Copilot CLI extension | The `@github/copilot-sdk` package; Copilot CLI |
| [orfi-kit-copilot-hooks](docs/skills/orfi-kit-copilot-hooks.md) | `copilot/hooks/orfi-kit.json` — registers the seven shared hook scripts as Copilot **native hooks** (`PreToolUse` sync, `PostToolUse` verifiers, `Stop` brevity + skill-contract) with `ORFI_HOOK_PLATFORM=copilot` payload contracts. Installs to `~/.copilot/hooks/`. | Copilot CLI native hooks | The seven scripts in `~/.claude/hooks/`; Git Bash on Windows |
| [orfi-kit-opencode-plugin](docs/skills/orfi-kit-opencode-plugin.md) | `opencode/plugins/orfi-kit-hooks.ts` — runs the same scripts for OpenCode: sync gate (`tool.execute.before`), format verifiers (`tool.execute.after`), conventions at chat start (`chat.system.transform`). Installs to `~/.config/opencode/plugins/`. No Stop event → brevity + skill-contract are not ported (honest gap). | OpenCode plugin | The seven scripts; Git Bash on Windows |
| [orfi-kit-codex-hooks](docs/skills/orfi-kit-codex-hooks.md) | `codex/hooks.json` + `codex/AGENTS.md` — registers **5 of 7** hook scripts as Codex **native hooks** (`PreToolUse` sync gate, `PostToolUse` format verifiers) with `ORFI_HOOK_PLATFORM=codex` payload contracts, and ships the guardrails + C#/C++ conventions as Codex **global rules** (read every session). Skills land in `~/.agents/skills`, invoked by bare name. Stop contracts (brevity, skill-contract) are **not wired** — Codex has no stable Stop surface, so they run as an explicit checklist instead (honest gap). Installs to `~/.codex/hooks.json` + `~/.codex/AGENTS.md` — **merged, never overwritten**. | Codex CLI native hooks | The seven scripts in `~/.claude/hooks/`; Git Bash on Windows; up-to-date Codex CLI |

## Install

The repo ships two equivalent installers (a maintenance pair). Run either and pick which
runtime(s) you want (Claude Code, OpenCode, GitHub Copilot CLI, OpenAI Codex CLI — one or several).

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

### Hook wiring

**Claude Code.** The installer places the seven hook scripts in `~/.claude/hooks/` and wires
each into `~/.claude/settings.json`:

- `orfi-kit-enforce-sync.sh` → a **PreToolUse/Bash** entry (blocks unsynced `git push`).
- `orfi-kit-enforce-brevity.sh` → a **Stop** entry (blocks over-long replies; ~25-line limit,
  override with `ORFI_BREVITY_MAX_LINES`, auto-lifted when the user asks for depth).
- `orfi-kit-verify-skill-contract.sh` → a **Stop** entry (blocks a skill's final report when a step
  it mandates has no `tool_use` record in the transcript; reads `CONTRACT.conf` beside the skill,
  disable with `ORFI_SKILL_CONTRACT_OFF=1`).
- `orfi-kit-load-csharp-conventions.sh` and `orfi-kit-load-cpp-conventions.sh` → two
  **PreToolUse/`Write|Edit|MultiEdit`** entries that emit the repo's own rules *before* a file is
  written. Advisory.
- `orfi-kit-verify-csharp-format.sh` and `orfi-kit-verify-cpp-format.sh` → two
  **PostToolUse/`Write|Edit|MultiEdit`** entries that run the real formatters *after* a file is
  written. Advisory by default; `ORFI_{CSHARP,CPP}_FORMAT_BLOCKING=1` makes them block.

Matchers are **tool names, not file globs** — Claude matchers cannot match `*.cs`. Each hook filters
paths itself from `.tool_input.file_path`, so a hook wired to `Write` exits 0 silently on files it
doesn't own.

Every merge is **idempotent** and **non-destructive**: your existing settings are preserved,
re-running the installer never duplicates an entry, and a `settings.json.bak` snapshot is written
before any change. A one-time `settings.json.orfi-orig` also preserves what existed *before*
orfi-kit ever touched the file — on a re-install, `settings.json` already contains our entries, so
the rolling `.bak` alone would lose your true original. Decline the sync-hook prompt to get manual
wiring instructions instead. Uninstall removes all seven hook files and their settings entries.

> Auto-wiring requires `jq` (bash) — without it you'll get manual instructions. PowerShell uses
> built-in JSON support.

**Copilot CLI.** The same seven scripts become native hooks by placing `copilot/hooks/orfi-kit.json`
in `~/.copilot/hooks/` (see [orfi-kit-copilot-hooks](docs/skills/orfi-kit-copilot-hooks.md)). Five
events are registered: `PreToolUse`/`Bash` (sync), `PostToolUse`/`Write|Edit|MultiEdit` (both format
verifiers), and `Stop` (brevity + skill-contract). The two loaders are *not* registered there — the
guardrails extension injects the conventions at `onSessionStart`. Registered scripts run with
`ORFI_HOOK_PLATFORM=copilot`, so verdicts are Copilot JSON (`deny` / `block` / `additionalContext`)
rather than exit codes, and command-hook timeouts are fail-open.

**OpenCode.** The installer places `opencode/plugins/orfi-kit-hooks.ts` in
`~/.config/opencode/plugins/` (see [orfi-kit-opencode-plugin](docs/skills/orfi-kit-opencode-plugin.md)).
The plugin shells to the same scripts with `ORFI_HOOK_PLATFORM=opencode`:
`tool.execute.before` gates `git push`, `tool.execute.after` merges verifier findings into the tool
result, and `chat.system.transform` injects the conventions at chat start. OpenCode has **no Stop
event**, so brevity and skill-contract are not ported there — an honest gap, not a fake gate.

**Codex CLI.** The installer merges `codex/hooks.json` into `~/.codex/hooks.json` and appends
`codex/AGENTS.md` to `~/.codex/AGENTS.md` (see [orfi-kit-codex-hooks](docs/skills/orfi-kit-codex-hooks.md)).
Five events register: `PreToolUse`/`^Bash$` (sync gate, deny) and
`PostToolUse`/`Write|Edit|apply_patch` (both format verifiers, advisory). Codex has **no Stop event**
and no chat-start hook surface, so the brevity + skill-contract gates and the two convention loaders
are **not wired** — instead `AGENTS.md` carries the guardrails and the C#/C++ conventions, enforced as
an explicit checklist every session (honest gap, not a fake gate). Skills go to `~/.agents/skills`
and are invoked by **bare name** (Codex has no slash-command skill references). Because
`~/.codex/hooks.json` and `~/.codex/AGENTS.md` are the user's own files, the installer **merges**
(never overwrites): handlers are added when not already registered, and the `AGENTS.md` block goes
under a `# orfi-kit` marker with a `.bak` backup. Invalid JSON is left alone, with manual
instructions.

| | Sync gate | Load conventions | Verify a write | Brevity gate | Skill-contract gate |
| --- | --- | --- | --- | --- | --- |
| Claude Code | Yes — `PreToolUse/Bash` | Yes — 2 `PreToolUse` loaders | Yes — 2 `PostToolUse` | Yes — `Stop` | Yes — `Stop` |
| Copilot CLI | Yes — native `PreToolUse` | Yes — extension at `onSessionStart` | Yes — 2 native `PostToolUse` | Yes — native `Stop` | Yes — native `Stop` |
| OpenCode | Yes — plugin `tool.execute.before` | Yes — plugin at chat start (root probe) | Yes — plugin `tool.execute.after` (advisory) | **No — no Stop event** | **No — no Stop event** |
| Codex CLI | Yes — native `PreToolUse` | Yes — global rules (`AGENTS.md`) | Yes — 2 native `PostToolUse` (advisory) | **No — checklist in AGENTS.md** | **No — checklist in AGENTS.md** |

### Doc-checker scripts (all runtimes)

The installer also places six files from `scripts/` into the selected runtime's `scripts/` directory
(`~/.claude/scripts/`, `~/.config/opencode/scripts/`, `~/.copilot/scripts/`):

| Script | What it does |
| --- | --- |
| `check-xml-docs.ps1` / `.sh` | Exits 1 when a `public`/`protected`/`static` C# member lacks a `///` block |
| `check-doxygen-docs.ps1` / `.sh` | Same for exposed declarations in C++ **headers** (`.h .hpp .hh .hxx`); skips `.cpp`, since the API surface lives in the header |
| `setup-hooks.ps1` / `.sh` | One-time per clone: sets `core.hooksPath .githooks` so `.githooks/pre-commit` fires |

Each pair is a behavioural twin (PowerShell + bash), so a machine with only one of the two still
enforces. All take `--files <paths>`, `--staged`, or `--changed`.

**These are project tooling, not user-global skills** — which makes their resolution a two-rung
ladder, the same shape as the config authority ladder above:

1. **The reviewed repo's own `scripts/`** wins. The review skills call them by the *relative* path
   `scripts/check-…`, which resolves against that repo's cwd.
2. **The installed copy** is a fallback for a repo that has none.

Copying a checker into a project is still the better answer, because only then can that project's CI
and its `.githooks/pre-commit` run it. The installer never writes into your project.

`.githooks/pre-commit` runs both checkers over the **staged** files and blocks the commit on a
violation (`git commit --no-verify` to bypass). `--staged` is right there because the index *is* the
scope — whereas the review skills use `--files` against the branch diff, since at review time the
index is usually empty and `--changed` would inspect nothing while exiting 0. Wire it per repo with
`setup-hooks`; uninstall does **not** unwire it, so run `setup-hooks --unset` (`-Unset`) in any repo
where you no longer want it.

**Hooks must not require anything the installer doesn't guarantee.** A hook runs on every reply or
every tool call, long after install, on whatever machine the user has. If it needs a binary that
isn't there it will usually take the quiet path — exit 0 and enforce nothing — so a guardrail that
was wired correctly reads as a guardrail that passes. That is strictly worse than not shipping it.

So when writing a hook: parse with `jq` if it's on PATH, but always keep a shell fallback (`sed`,
`grep`, parameter expansion), and never make the absence of a tool the reason the hook stops
checking. If a hook genuinely cannot do its job, it should say so on stderr rather than return
success. The brevity hook was silently inert on any machine without `jq` until this was fixed —
PowerShell installs were affected worst, because install-time wiring succeeds there without `jq`
and nothing warned that the hook still needed it at runtime.

### Copilot enforcement

Installing for GitHub Copilot CLI puts **two** surfaces in place that work together:

- **The SDK extension** — copied to `~/.copilot/extensions/orfi-kit-guardrails/`. It injects the
  guardrails and the C#/C++ conventions at `onSessionStart` (scoped to the languages actually
  present), and keeps an `onUserPromptSubmitted` nudge that corrects an over-long **previous** reply.
  The SDK itself has no post-response event, so the nudge lands a turn late — a nudge, not a gate.
- **The native hooks** — `~/.copilot/hooks/orfi-kit.json`. Copilot CLI's hook events give the kit
  exactly the events the SDK extension lacks. The same seven scripts that run on Claude Code are
  registered here and emit Copilot's JSON contracts under `ORFI_HOOK_PLATFORM=copilot`:
  `PreToolUse`/`Bash` blocks an out-of-sync `git push` (deny), the two `Stop` hooks block over-long
  replies and skill reports without record (block JSON, honouring `stop_hook_active` and Copilot's
  8-consecutive-blocks guard), and two `PostToolUse`/`Write|Edit|MultiEdit` hooks verify a written
  file (advisory `additionalContext`).

So the old "Claude gates, Copilot nudges" asymmetry is **gone for the events Copilot CLI supports**:
sync, brevity, skill-contract, and format verification all gate or check on both platforms. The
remaining honest gap is OpenCode, which has no Stop event — see the matrix in **Hook wiring**.

Both sides still keep their own copy of the phrase list that lifts the brevity limit — a regex in
`extension.mjs`, a `case` in the Stop hook. They have drifted before (the extension was once missing
"elaborate" and "show more"), so **change them together.**

The convention rule text is likewise duplicated: prose in `extension.mjs`, shell in the two
`orfi-kit-load-*-conventions.sh` hooks. Same reason as the brevity list (different platforms, no
shared code) and the same instruction — **change them together.** And both sides defer to the same
authority, in this order:

1. **The repo under review always wins.** If it has an `.editorconfig`, `.clang-format`, or
   `.clang-tidy`, that is the contract and nothing overrides it.
2. **Otherwise the kit's own baseline applies**, read live from the code-review skills' `CONFIG.md`
   and enforced as the contract for that repo. The Claude hooks read it off disk rather than
   embedding a copy, so the baseline can never drift from the `CONFIG.md` that documents it.
3. **If neither exists**, nothing is enforceable: say so and follow the prevailing pattern of the
   file being edited. Never substitute general language habit for a rule nobody set.

Rung 2 is honest about its ceiling: with no config in the repo, `dotnet format` and `clang-format`
have nothing to read, so the baseline binds the author rather than a tool. Adopting it as the repo's
own config is what makes it enforceable by the build and CI — and the hooks are **read-only**, so
they will never write it for you.

## Uninstall

Run the same installer with `--uninstall` (bash) or `-Uninstall` (PowerShell) and **select the same
runtime(s) you installed for** — it only cleans what you select, so anything else is left behind.
Skills, commands, all seven hook files + their `settings.json` entries, the Copilot hooks registration
(`~/.copilot/hooks/orfi-kit.json`), the Codex hooks registration (`~/.codex/hooks.json`) + `AGENTS.md`
block (`~/.codex/AGENTS.md`, restored from its `.bak` when one was written), the OpenCode plugin, the
six `scripts/` files, and the Copilot extension are removed. The scripts directory is deleted only if uninstall emptied it, so a
directory holding scripts of your own survives.

Two things uninstall deliberately does **not** undo: `core.hooksPath` in any repo where you ran
`setup-hooks` (run `setup-hooks --unset` there), and any copy of a checker you placed in a project's
own `scripts/` — that file belongs to the project now.

**On re-install:** files are replaced wholesale (`rm -rf` then copy), so the repo is the source of
truth and local edits to installed copies are lost; `settings.json` is merged rather than
overwritten, so entries never duplicate. Re-running is therefore the update path. It only ever adds
and replaces, though — a skill that a later version *renames or drops* leaves its old copy behind,
since the installer writes its current list rather than diffing a manifest. Uninstall, then install,
when you want to be certain.

## License

MIT — see `LICENSE`.
