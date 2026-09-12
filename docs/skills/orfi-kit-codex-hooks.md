# orfi-kit-codex-hooks

> Registers orfi-kit's shared hook scripts as OpenAI Codex CLI **native hooks** and ships the guardrails + conventions as Codex **global rules**, so Codex gates pushes and verifies written files like the other runtimes.

## What it does

`codex/hooks.json` is Codex's native hook registration. It installs to `~/.codex/hooks.json` (a user-level settings file), while `codex/AGENTS.md` installs to `~/.codex/AGENTS.md` (Codex's global rules file, read at session start — like Claude Code's `~/.claude/CLAUDE.md`). The 21 skills land in Codex's user-scope skill home, `~/.agents/skills`, and are invoked by **bare name** (`orfi-kit-commit`, `orfi-kit-code-review`, ...) — Codex has no slash-command skill references.

The registered scripts are the **same seven** the installer deploys to `~/.claude/hooks/`. They run with `ORFI_HOOK_PLATFORM=codex`, which makes them follow Codex's hook contract (see the payload section below).

## Which hooks are registered

| Codex event | Matcher | Script | Effect |
| --- | --- | --- | --- |
| `PreToolUse` | `^Bash$` | `orfi-kit-enforce-sync.sh` | Blocks an out-of-sync `git push` (deny) |
| `PostToolUse` | `Write\|Edit\|apply_patch` | `orfi-kit-verify-csharp-format.sh` | Verifies a `.cs` write (advisory) |
| `PostToolUse` | `Write\|Edit\|apply_patch` | `orfi-kit-verify-cpp-format.sh` | Verifies a C/C++ write (advisory) |

That is **5 of 7** hooks — deliberately. The `codex/hooks.json` `description` field documents the gaps.

**Not wired, on purpose:**

- **The two `Stop` contracts — brevity and skill-contract.** Codex has no stable post-reply (Stop) hook event with a transcript-shaped payload like Claude Code and Copilot CLI expose. A hook wired to a surface that never fires is a silent fake gate — *"a hook that always passes is worse than no hook"* — so these two run as an explicit **checklist in `AGENTS.md`** instead of a wire.
- **The two convention loaders.** Codex has no chat-start hook surface and its matchers are tool-name regexes, so the per-write loader pattern doesn't map. Instead `AGENTS.md` carries the C# and C++ conventions verbatim (sorted, third-party and trusted-file escapes, safety wording) and they load **every session**, which is strictly more coverage than a per-write loader.

## Payload contracts

Codex handler config has **no `env` field** — only `type` / `matcher` / `command` / `timeout` / `statusMessage` — and commands run through a shell, so `$HOME` and `$(...)` expand at runtime. The platform is carried **inline in the command string**:

```
ORFI_HOOK_PLATFORM=codex bash "$HOME/.claude/hooks/orfi-kit-enforce-sync.sh"
```

The scripts emit Codex's payload contracts (exit 0, JSON on stdout):

- **`PreToolUse` (sync): deny** — `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`. The `permissionDecisionReason` is an instruction to the model, so it carries the "run /orfi-kit-sync-branch first" guidance like Claude Code.
- **`PostToolUse` (verifiers): advisory** — `hookSpecificOutput` with `hookEventName:"PostToolUse"` and `additionalContext`, the same shape a Claude Code hook emits by default. Verifiers stay advisory (Codex has no PostToolUse block channel); `ORFI_*_FORMAT_BLOCKING` remains Claude-only.
- **Timeout** mirrors the other runtimes: sync 10, verifiers 120.

## Behavior / rules

- Codex matchers are **shell-style regexes**: `^Bash$` for PreToolUse, `Write|Edit|apply_patch` for PostToolUse.
- **The user's files are merged, never overwritten.** `~/.codex/hooks.json` and `~/.codex/AGENTS.md` belong to the user. The installer merges handlers into an existing `hooks.json` (dedup by command; invalid JSON is left untouched with manual instructions) and appends the orfi-kit block to `AGENTS.md` under a `^# orfi-kit` marker with a `.bak` backup. Uninstall filters the handlers out and restores the `.bak` / removes the block.
- Skills are copied to `~/.agents/skills` (symlinked with `--link`); the guardrails skill is picked up from there automatically because the `AGENTS.md` block points at `~/.agents/skills/orfi-kit-guardrails/SKILL.md`.
- Because the two Stop contracts live as prose in `AGENTS.md` while their script twins stay in the repo's `claude/hooks/`, wording that overlaps must be kept in step — **change them together.**

## Prerequisites

- The seven hook scripts deployed to `~/.claude/hooks/` (the installer does this whenever any runtime that needs them is selected — Codex included). On Windows Codex runs hooks through Git Bash, so Git Bash must be installed.
- Up-to-date Codex CLI. Registration surfaces can move — reference: `https://developers.openai.com/codex/skills`.

## Notes

- Hook contracts were ported against the Codex CLI hooks doc; verify against current docs when updating (handler schema, matcher semantics, stdout payload shapes).
- Priority order is the repo's authority ladder: project rules > user global rules (`~/.codex/AGENTS.md`) > built-in defaults.
- See the README's "Codex CLI" section for the full four-platform matrix.