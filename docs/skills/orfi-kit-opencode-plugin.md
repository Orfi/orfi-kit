# orfi-kit-opencode-plugin

> Gives OpenCode the same enforcement surface as Claude Code by running the kit's seven hook scripts through the opencode plugin API.

## What it does

`opencode/plugins/orfi-kit-hooks.ts` loads in OpenCode and shells out to the **same seven hook scripts** that Claude Code and Copilot CLI use, with `ORFI_HOOK_PLATFORM=opencode` so the scripts emit opencode's output JSON. The installer places it at `~/.config/opencode/plugins/orfi-kit-hooks.ts`; it uses only Node built-ins plus the opencode plugin API, so there is no package or build step.

## Hook wiring

| opencode hook | Script | Effect |
| --- | --- | --- |
| `tool.execute.before` (git push) | `orfi-kit-enforce-sync.sh` | Throws → blocks an out-of-sync push (gate) |
| `tool.execute.after` (write/edit) | `orfi-kit-verify-{csharp,cpp}-format.sh` | Merges findings into the tool result (advisory) |
| `experimental.chat.system.transform` | `orfi-kit-load-{csharp,cpp}-conventions.sh` | Injects the repo's conventions at chat start (cached 1h per repo) |

Registrations are non-destructive: only `tool.execute.before` on `git push`, `tool.execute.after` on write-equivalent tools, and `chat.system.transform` are hooked, and only when the hook scripts exist. Runtime errors log and fall through rather than breaking the session.

## Honest gaps

- **OpenCode has no Stop event**, so the two gates that depend on it — `orfi-kit-enforce-brevity` and `orfi-kit-verify-skill-contract` — are **not ported**. The plugin documents this instead of faking a Stop-equivalent (the README's "no Stop event" row). The guardrails skill is still injected by `chat.system.transform`, so brevity stays declarative.
- **Conventions are probed at the worktree root, not per file** — the plugin's loader probes `<root>/orfi-kit-probe.cs` / `.cpp` once per chat, a deliberate approximation of Claude Code's per-write loader. A repo whose config lives under a subdirectory gets the baseline, not the file-specific rules.
- **Git Bash is required on Windows.** The plugin resolves the first Git Bash candidate (`C:\Program Files\Git\bin\bash.exe`, `C:\Program Files (x86)\Git\bin\bash.exe`, then `bash` on PATH — which on Windows may be WSL's). If none is found it fails **open**: nothing is enforced and the omission is logged — enforcement is never invented. Install Git Bash to get the gates back.

## Behavior / rules

- `tool.execute.after` merges the verifier's parsed `{"output":{"output":"…"}}` into the tool result as additional context, so findings reach the model the way `additionalContext` does on other platforms. Verifiers stay advisory; there is no block channel.
- The sync gate throws with the script's message on a non-zero exit (`ORFI_HOOK_PLATFORM=opencode` keeps Claude's exit-code contract), so out-of-sync pushes are blocked before the Bash tool runs.
- Loader output is only injected when it carries a `--- <path>` heading or the `ENFORCING the orfi-kit baseline` marker — "repo encodes nothing" is already the default behaviour and is not re-injected as noise.

## Notes

- The plugin runs the same scripts, so the rule-content duplication caveat is unchanged: change hook scripts and `extension.mjs` together.
- See the README's "Copilot enforcement" section for the full three-platform matrix and the OpenCode row.