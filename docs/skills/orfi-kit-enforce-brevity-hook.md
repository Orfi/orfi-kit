# orfi-kit-enforce-brevity-hook

> Blocks over-long assistant replies — counts the lines in a finished reply and, past ~25, feeds it back with an instruction to shorten.

## What it does

This is a global `Stop` hook that fires when the assistant finishes a reply. It reads the session transcript, extracts the last assistant text turn, and counts its lines. If the count exceeds the limit (25 by default, ~one printed page), the hook exits non-zero and the reply is fed back to the assistant with an instruction to rewrite it far shorter.

It exists because advisory instructions didn't bind. The guardrails skill has always asked for concise replies, and page-length answers to small questions kept shipping anyway. This hook makes the brevity rule mechanical rather than aspirational — the same reason the sync hook exists alongside the git conventions skill.

## When it fires / how to invoke

Passive — it runs automatically at the end of every assistant turn. You don't invoke it. There are three cases where it deliberately does nothing:

- **The reply is within the limit.** Exits 0 silently.
- **The user asked for depth.** If the last user prompt contains a depth cue, the limit is lifted for that turn.
- **It already fired this turn.** Claude Code sets `stop_hook_active` on the re-entry; the hook checks that flag and exits 0 rather than blocking twice. Without this it would loop.

## Prerequisites

- `jq` — the hook parses the JSON payload and the JSONL transcript with it. Without `jq` it cannot read the payload safely and exits 0 (fails open, never blocks).
- A Stop-hook-capable runtime (Claude Code, or Copilot CLI with the kit's native hooks — see Notes).
  OpenCode has no Stop event and the plugin does not port this hook.

## Behavior / rules

- Threshold is **25 lines**, overridable per-environment with `ORFI_BREVITY_MAX_LINES`.
- The payload arrives on stdin as JSON. An empty payload exits 0.
- `stop_hook_active: true` exits 0 — the loop guard.
- `transcript_path` is read from the payload; a missing or non-existent path exits 0.
- The transcript is JSONL, one message object per line. The hook takes the **last** `assistant` message and joins its `text` content blocks; tool calls and thinking blocks aren't counted. An empty result exits 0.
- The **last** `user` message is lowercased and matched against depth cues: `in full`, `in detail`, `detailed`, `explain in depth`, `in depth`, `walk me through`, `step by step`, `long version`, `be thorough`, `full detail`. Any match lifts the limit for that turn.
- Over the limit, the hook writes the rewrite instruction to stderr and exits **2**. On exit 2, stderr is fed back to the assistant.
- Every failure path is fail-open: no payload, no `jq`, no transcript, unparseable transcript, or no assistant text all exit 0. The hook never blocks because it couldn't do its job.

## Example

The assistant answers a one-line question with a 40-line reply:

```
BLOCKED: your reply is 40 lines; the limit is 25 (~one page).

Rewrite it far shorter:
  - Lead with the answer or the single decision that's actually needed.
  - Cut restated context, hedging, and options you won't pursue.
  - One idea per line. No walls.

If the user genuinely needs depth, they'll ask ('in detail', 'in full') and the
limit lifts. Default is brief.
```

The assistant rewrites; the second attempt isn't re-blocked (`stop_hook_active`), so a stubborn reply costs one retry, not an infinite loop.

Raise the limit for a session that genuinely needs longer output:

```bash
export ORFI_BREVITY_MAX_LINES=60
```

## Installation

The installer copies the hook to `~/.claude/hooks/orfi-kit-enforce-brevity.sh` and wires it into `~/.claude/settings.json` under `.hooks.Stop`:

```json
{
  "hooks": [
    { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh\"", "timeout": 10 }
  ]
}
```

`Stop` entries take no `matcher` — unlike the `PreToolUse` sync hook, `Stop` events aren't tool-scoped. The merge is idempotent (re-running the installer won't duplicate the entry) and non-destructive (a `settings.json.bak` is written first). Without `jq`, the installer prints the JSON above for manual wiring. Uninstall removes the hook file and its settings entry.

## Notes

- Enforces the brevity rule in the `orfi-kit-guardrails` skill, which points back at this hook and tells the assistant to treat it as a hard rule.
- On Copilot CLI the same script is registered as a **native `Stop` hook** by
  `~/.copilot/hooks/orfi-kit.json` and blocks over-long replies just as it does on Claude Code
  (emitting a block-decision JSON instead of a non-zero exit; Copilot bounds the loop with its own
  8-consecutive-blocks guard). The `orfi-kit-guardrails-extension`'s next-turn nudge remains as the
  fallback for sessions without native hooks. OpenCode has no Stop event, so this hook is not ported
  to the plugin.
- Installed globally under `~/.claude/hooks/`, so it applies across all projects.
