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

- The seven hook scripts deployed to `~/.claude/hooks/` (the installer does this when any runtime that needs them is selected — Copilot included). On Windows the `powershell` field invokes the `orfi-run-hook.ps1` runner installed next to them; both fields carry the script ref as an **absolute forward-slash path** baked at install time. Copilot CLI `1.0.83` loads hooks at **session start**, so re-running the installer mid-session does not take effect until Copilot fully restarts.

## Behavior / rules

- Installed by the twin installers to `~/.copilot/hooks/orfi-kit.json`; uninstall removes it. It coexists with any other `*.json` in that directory (e.g. `gsd-session.json`).
- `env` carries `ORFI_HOOK_PLATFORM=copilot`. Both `bash` and `powershell` fields target the script with an **absolute forward-slash path baked in by the installer** — the shipped `orfi-kit.json` is a template whose `@ORFI_COPILOT_HOME@` placeholder is replaced at install time (`cygpath -m "$HOME"` in the sh installer, `$env:USERPROFILE` in the ps1 installer). The two fields differ deliberately:
  - **`bash` field: inline mount-style resolver.** The direct bash host evaluates the body, which tries the baked `C:/Users/…` form, then `/mnt/<drive>/…` (WSL), then `/c/…` (Git Bash) before `bash`-ing the script.
  - **`powershell` field: a zero-quote path to a runner.** It is just `& '@ORFI_COPILOT_HOME@/.claude/hooks/orfi-run-hook.ps1' <hookname>` — no `$`, no quotes, no inline logic. Three hard-won rules keep these hooks green on Windows:
  - **Do not resolve `$HOME` at runtime.** The bash Copilot spawns on Windows reports `$HOME=/home/<user>` (not the profile), so `bash "$HOME/.claude/hooks/…"` becomes `bash /home/orfi/…: No such file`. This is why the path is absolute and baked at install.
  - **Do not put any inline logic in the `powershell` field.** The PowerShell-spawned bash on Windows is the **WSL shim** (`C:\Windows\system32\bash.exe`), which mangles inline double-quotes and `=` inside a `bash -c '…'` body — `d="C"; echo d=$d` prints `d=` and `$(…)`/`${…}` come back empty, so every inline body silently resolves to nothing. A bare-argument path (`& bash '/mnt/c/…'`) survives intact, which is exactly what the ps1 runner depends on. The runner probes the `C:/…`, `/c/…`, `/mnt/c/…` forms via `bash -c 'test -f …'` (quote-free, shim-safe), then invokes the first hit.
  - **Do not pass the path as a separate argument with backslashes.** `& bash "$env:USERPROFILE\.claude\hooks\…"` gets mangled/stripped at the PowerShell→bash boundary (backslashes stripped → `C:Users…: No such file`), and every such hook then fails **closed** in Copilot — one mangled hook denies all tool calls. Keep paths forward-slash and single-quoted as shipped.
- **Installed hooks are LF-normalized.** The installer rewrites installed `.sh` files (`tr -d '\r'` / `[IO.File]::WriteAllText`) because a stale checkout or `core.autocrlf` can leave CRLF on disk and bash aborts with `$'\r': command not found`. `orfi-run-hook.ps1` rides along in `~/.claude/hooks/` and is installed by the Copilot hooks step of both installers.
- **Cross-tool trap (not this file):** Copilot CLI also loads a *repository's* `.claude/settings.json` / `.claude/settings.local.json` as extra hook sources. On Windows such hooks fail closed too: Copilot runs the `command` string via PowerShell and does **not** set `$CLAUDE_PROJECT_DIR`, so a Claude-style `bash "$CLAUDE_PROJECT_DIR/.claude/hooks/…"` becomes `bash /.claude/hooks/…` (github/copilot-cli#4001). Symptom: `Denied by preToolUse hook from "repo settings" (hook errored)` for *every* tool call. Workaround for those repos: wrap each hook command as `bash -c 'd=${CLAUDE_PROJECT_DIR:-}; …resolved from stdin .cwd…'`, or set `disableAllHooks`/strip the hooks block — the kit only writes its hooks to user-level `~/.copilot/hooks/`, so it never hits this path itself.
- Matchers use Claude semantics: `Bash`, and `Write|Edit|MultiEdit` as a pipe-separated list (this file uses **PascalCase** event names, which Copilot CLI accepts natively with snake_case payload fields).

## Notes

- The verdict is delivered as JSON, not an exit code — a consumer must not read `$?` from a Copilot hook.
- The rule-content duplication rule still applies: the convention text and the brevity phrase list each live in both `extension.mjs` and the hook scripts. **Change them together.**
- See the README's "Copilot enforcement" section for the full three-platform matrix.