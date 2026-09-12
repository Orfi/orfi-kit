# orfi-kit-verify-skill-contract-hook

> Blocks a skill's final report when a step that skill mandates has no `tool_use` record in the session transcript.

## What it does

This is a global `Stop` hook that fires when the assistant finishes a reply. It looks for an open **skill contract**, and if the reply is a final report, it checks every mandated step against what the session transcript actually records. Anything missing, and the hook exits non-zero — the report is fed back with a list of the specific steps that never ran.

It exists because the code-review skills' prose didn't bind. `orfi-kit-csharp-code-review` mandates two companion skills (`/orfi-kit-xml-docs`, `/security-review`) and a tool lane (`dotnet format` / `build` / `test`). In one real session a review was reported three times with both companions never invoked — their analysis substituted inline and presented as the gate — then reported a fourth time claiming one of them had run. The instructions were explicit and compelling, and they lost to the model's own confidence that it already knew the answer.

The transcript is what makes it work. Claude Code records every tool call as a harness-authored `tool_use` entry:

```json
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill",
 "input":{"skill":"security-review"}}]}}
```

The model authors the `input`; it does not author the **record**. It can write "invoked `/security-review`" into prose, but it cannot make that line exist. So the record is evidence and the report is only a claim — and this hook reads evidence.

## Contracts

A contract is a `CONTRACT.conf` file sitting beside a skill's `SKILL.md`, so a skill and its enforced rules install together and cannot drift apart. Shipped with:

- `orfi-kit-csharp-code-review` — both companions, the full tool lane, the scope diff, plus the `--changed` and `@{u}` traps.
- `orfi-kit-cpp-code-review` — the two companions, the scope diff, plus the `--changed`, `@{u}`, and `clang-format -i` traps. Deliberately requires **less** of the toolchain: missing `clang-format`, `clang-tidy`, and `compile_commands.json` are the norm in C++, and a gate that fires on correct behaviour gets bypassed and then ignored.

Directive format, `::`-separated, one per line:

```
require::<skill|bash>::<pattern>::<label>::<claim-regex>
forbid::<skill|bash>::<pattern>::<label>::<why>
report-marker::<literal>
report-min::<n>
```

`<pattern>` is an exact skill id, or an extended regex matched against the recorded Bash command. The optional `<claim-regex>` changes the wording of a failure: when the report *asserts* a step ran but no record exists, the hook names it a fabricated claim rather than a plain omission — a skipped step is an oversight, a skipped step reported as done is a false statement.

## When it fires / how to invoke

Passive — you never invoke it. It acts only when both conditions hold:

1. **A contract is open.** The contract opens at the most recent invocation of a contract-bearing skill. Both invocation forms count: the `Skill` tool (`{"skill":"x"}`) *and* a slash command (`<command-name>/x</command-name>`). Matching only the former would have missed the real incident entirely — there the review started as a slash command and the `Skill` tool appeared only in the remedial pass, hundreds of lines later, after the user caught the skip.
2. **The reply is report-shaped.** Recognised by the `report-marker` headings the skill's own Report section mandates, requiring several (`report-min`, default 3) so a passing mention of "Verdict" mid-conversation doesn't trip it.

Only records *after* the contract opened are counted, so a previous pass's satisfied step cannot excuse a later pass that skipped it. Mid-review turns are never touched: this gates the deliverable, not the work.

## Attempt, not success

A `require` row is satisfied by the **record of the call, not its exit code**. An unavailable skill, an uninstalled `dotnet`, a solution that won't restore — each leaves a record and each satisfies the row.

That is deliberate. It preserves the honest `skipped (unavailable)` verdict the skills allow, while removing the option of *deciding* a step was unnecessary without ever trying it. If a step genuinely cannot run, run it anyway and let the failure be the evidence; it costs one command and turns a guess into a reportable fact.

## Deliberately no conversational escape hatch

Unlike the brevity hook — where "in detail" lifts the limit — there is no phrase that lifts this gate. A gate the model can talk its way past is the failure mode being fixed, not a feature. Rewriting the report without new records blocks again, because the record is checked, not the wording.

Turning it off is the user's decision, made outside the conversation: `ORFI_SKILL_CONTRACT_OFF=1`.

## Prerequisites

Nothing beyond a Stop-hook-capable Claude Code. Uses `jq` when present and falls back to `grep`/`sed`, so a missing tool is never the reason enforcement stops. `ORFI_SKILL_DIRS` overrides where contracts are searched for (defaults to `~/.claude/skills`).

Loop-safe: Claude Code sets `stop_hook_active` on re-entry, and the hook exits 0 rather than blocking the same reply twice.

## Copilot

Now enforced. `~/.copilot/hooks/orfi-kit.json` registers this same script as a native `Stop` hook
(`ORFI_HOOK_PLATFORM=copilot`). Copilot's payload arrives with snake_case fields (`transcript_path`,
`stop_hook_active`), and the verdict is a **block decision** JSON (`{"decision":"block","reason":"…"}`
on stdout, exit 0) instead of Claude's non-zero exit. Copilot bounds the rewrite loop with its own
8-consecutive-blocks guard; the script still honours the `stop_hook_active` re-entry flag.

**Transcript-shape honesty guard.** The Stop scripts were written against Claude transcripts, so on
Copilot they `grep` the transcript for `"type":"assistant"` before enforcing. A transcript that does
not match gets a *"transcript is not Claude-shaped … Refusing to fake a pass"* note and a clean exit —
a hook must never judge a format it doesn't understand.

**OpenCode has no Stop event**, so the plugin does not port this hook; the gap is documented in
`orfi-kit-opencode-plugin` rather than faked.

The Copilot skill copies carry `CONTRACT.conf` as the single source of truth, headed by a notice that
it is mechanically enforced when the native hooks are installed and a checklist otherwise. Their C#
and C++ contracts drop the `security-review` row, because Copilot CLI ships no such skill and
requiring one that cannot exist would make the gate fire on correct behaviour.
