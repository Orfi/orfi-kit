# orfi-kit-copilot-hooks

> Registers orfi-kit's seven hook scripts as GitHub Copilot CLI **native hooks**, so Copilot gates pushes, blocks over-long replies, and verifies written files like Claude Code does.

## What it does

`copilot/hooks/orfi-kit.json` is a user-level hook registration. Copilot CLI loads every `*.json` in `~/.copilot/hooks/`, so installing it registers the **same seven scripts** the installer deploys to `~/.claude/hooks/` as native Copilot hooks. The scripts run with `ORFI_HOOK_PLATFORM=copilot`, which makes them emit Copilot's payload contracts instead of Claude Code's (see the payload section below).

It complements — it does not replace — the guardrails SDK extension (`orfi-kit-guardrails-extension`). The extension injects guardrails and conventions at session start; these native hooks add the events the SDK extension lacks (`Stop`, `PostToolUse`), which is exactly why Claude was previously the only gating platform.

## Which hooks are registered

| Copilot event | Matcher | Script | Effect |
| --- | --- | --- | --- |
| `PreToolUse` | `Bash` | `orfi-kit-enforce-sync.sh` | Blocks an out-of-sync `git push` (deny) |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `orfi-kit-verify-csharp-format.sh` | Verifies a `.cs` write (advisory) |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `orfi-kit-verify-cpp-format.sh` | Verifies a C/C++ write (advisory) |
| `Stop` | — | `orfi-kit-enforce-brevity.sh` | Blocks an over-long reply (block) |
| `Stop` | — | `orfi-kit-verify-skill-contract.sh` | Blocks a report that skipped a mandated skill step (block) |

The two convention **loaders** are deliberately **not** registered here: the guardrails extension already injects the same rules at `onSessionStart`, so a per-write loader would duplicate context that is already in the transcript. Claude Code keeps loader hooks because the SDK there has no session hook.

## Payload contracts

Every script branches on `ORFI_HOOK_PLATFORM` and translates its verdict into Copilot's JSON contracts (exit 0, JSON on stdout):

- **`PreToolUse` (sync): deny** — `{"permissionDecision":"deny","permissionDecisionReason":"…"}`. Copilot command hooks are **fail-closed**: a non-zero exit blocks the command, so the JSON form is the precise gate and the reason is shown to the user.
- **`Stop` (brevity, skill-contract): block** — `{"decision":"block","reason":"…"}`. Copilot forces the assistant to rewrite under the given reason; an 8-consecutive-blocks guard bounds the loop. The payload arrives with snake_case fields (`transcript_path`, `stop_hook_active`); the scripts honour the re-entry flag the way Claude Code's `stop_hook_active` works.
- **`PostToolUse` (verifiers): advisory** — `{"additionalContext":"…"}`. Copilot appends `additionalContext` to the model's tool result. There is no block semantics on PostToolUse return, so `ORFI_*_FORMAT_BLOCKING` remains Claude-only; the verifiers report and the model acts.
- **Timeout is fail-open** for command hooks: `timeoutSec` mirrors Claude Code (sync 10, verifiers 120, brevity 10, skill-contract 30), and a timed-out command lets the call through rather than inventing a verdict.

## Transcript-shape honesty guard

The `Stop` scripts were written against Claude transcripts. On Copilot the transcript is expected to be Claude-shaped, but the hooks verify it anyway: before enforcing, each Stop script `greps` for `"type":"assistant"` and, if the shape doesn't match, prints a *"transcript is not Claude-shaped … Refusing to fake a pass"* note and exits 0. A hook must never pretend to have enforced a format it doesn't understand.

## Prerequisites

- The seven hook scripts deployed to `~/.claude/hooks/` (the installer does this when any runtime that needs them is selected — Copilot included). On Windows the `powershell` field invokes Git Bash explicitly and must be present; the `bash` field path resolves `$HOME` at runtime.

## Behavior / rules

- Installed by the twin installers to `~/.copilot/hooks/orfi-kit.json`; uninstall removes it. It coexists with any other `*.json` in that directory (e.g. `gsd-session.json`).
- `env` carries `ORFI_HOOK_PLATFORM=copilot`. Both `bash` and `powershell` fields resolve the script via `$HOME` **inside a single-quoted `bash -c` body** (`& bash -c 'bash "$HOME/.claude/hooks/…"'`), so a Windows-style path never crosses the PowerShell→Git Bash argument boundary. Passing a `$env:USERPROFILE\.claude\…` path through that boundary mangles it (backslashes stripped → `C:Users…: No such file`), and every such hook then fails **closed** in Copilot — one mangled hook denies all tool calls. Keep the `bash -c '…'` quoting form exactly as shipped.
- **Cross-tool trap (not this file):** Copilot CLI also loads a *repository's* `.claude/settings.json` / `.claude/settings.local.json` as extra hook sources. On Windows such hooks fail closed too: Copilot runs the `command` string via PowerShell and does **not** set `$CLAUDE_PROJECT_DIR`, so a Claude-style `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/…"` becomes `bash /.claude/hooks/…` (github/copilot-cli#4001). Symptom: `Denied by preToolUse hook from "repo settings" (hook errored)` for *every* tool call. Workaround for those repos: wrap each hook command as `bash -c 'd=${CLAUDE_PROJECT_DIR:-}; …resolved from stdin .cwd…'`, or set `disableAllHooks`/strip the hooks block — the kit only writes its hooks to user-level `~/.copilot/hooks/`, so it never hits this path itself.
- Matchers use Claude semantics: `Bash`, and `Write|Edit|MultiEdit` as a pipe-separated list (this file uses **PascalCase** event names, which Copilot CLI accepts natively with snake_case payload fields).

## Notes

- The verdict is delivered as JSON, not an exit code — a consumer must not read `$?` from a Copilot hook.
- The rule-content duplication rule still applies: the convention text and the brevity phrase list each live in both `extension.mjs` and the hook scripts. **Change them together.**
- See the README's "Copilot enforcement" section for the full three-platform matrix.