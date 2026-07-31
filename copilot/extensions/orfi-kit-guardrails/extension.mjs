import { joinSession } from "@github/copilot-sdk/extension";

const GUARDRAILS = `
[ORFI GUARDRAILS — ALWAYS ACTIVE]
These constraints are non-negotiable. They govern every interaction regardless of task.

OPERATIONAL INTEGRITY: Be honest about progress. Never fabricate results. Surface bugs and technical debt immediately. Never break working code to mask errors.
TEST VERIFICATION: Read actual test output — not just exit codes. Report real pass/fail/skip/error counts. If output is ambiguous, say so.
VERIFY BEFORE DONE: Confirm changes compile/run before claiming success. Never report partial work as complete.
READ BEFORE MODIFYING: Always read a file before editing it. Never generate full replacements from memory.
SCOPE DISCIPLINE: Only change what was asked for. Mention improvements; don't silently apply them.
NO SILENT RETRIES: Disclose every failure before trying a different approach.
VERSION CONTROL: Resolve merge conflicts properly. Never delete peer work. Respect session boundaries.
NO HALLUCINATED REFERENCES: Verify files, functions, classes, and APIs exist before referencing them.
COMPLETE ROLLBACKS: Revert all of a change or explain what remains. Verify the codebase after rollback.
FOLLOW EXISTING PATTERNS: Match codebase conventions. Raise concerns about patterns; don't silently override.
NO DESTRUCTIVE COMMANDS: Never run git push --force, git reset --hard, rm -rf, DROP TABLE, branch deletion, or similar without explicit user confirmation. State consequences first. Prefer safe alternatives.
COMMUNICATION: Ask before assuming. Be concise. Use search tools when stuck.
BREVITY: Keep replies under ~25 lines (about one screen) by default. Give the answer or the single decision needed, then stop — no restating known context, no options you won't pursue, no re-explaining settled decisions. Surface ONE decision at a time, not stacked walls of questions. Expand only when the user asks for depth ("in full", "in detail", "walk me through").
`;

// Soft brevity limit (lines) for the previous assistant turn. The Copilot SDK
// has no post-response Stop event, so we measure on the NEXT prompt and inject a
// correction — a turn later than Claude Code's blocking Stop hook, but it still
// keeps replies short over a conversation.
const BREVITY_MAX_LINES = 25;
// Keep this list in step with the same list in claude/hooks/orfi-kit-enforce-brevity.sh.
// The two are maintained separately because they run on different platforms, so they
// drift: this one previously lacked "elaborate" and "show more", meaning a caller could
// ask for depth here and still get the brevity nudge.
const DEPTH_REQUEST = /\b(in full|in detail|detailed|in depth|walk me through|step by step|long version|be thorough|full detail|elaborate|full version|more detail|show more|more info|expand on|tell me more|the whole|everything|full report|comprehensive|deep dive|unabridged|no limit|as long as)\b/i;

const session = await joinSession({
    hooks: {
        onSessionStart: async () => {
            await session.log("Orfi guardrails active");
            return { additionalContext: GUARDRAILS };
        },
        // Measure the assistant's last reply; if it ran long, nudge on this turn.
        onUserPromptSubmitted: async (ctx) => {
            try {
                const prompt = String(ctx?.prompt ?? "");
                if (DEPTH_REQUEST.test(prompt)) return {};

                const msgs = (typeof session.getMessages === "function")
                    ? await session.getMessages()
                    : (ctx?.messages ?? []);
                const lastAssistant = [...(msgs ?? [])].reverse()
                    .find((m) => m?.role === "assistant");
                const text = typeof lastAssistant?.content === "string"
                    ? lastAssistant.content
                    : (lastAssistant?.content ?? [])
                        .filter((c) => c?.type === "text")
                        .map((c) => c.text).join("\n");
                if (!text) return {};

                const lines = text.split("\n").length;
                if (lines > BREVITY_MAX_LINES) {
                    return {
                        additionalContext:
                            `[ORFI BREVITY] Your previous reply was ${lines} lines; the limit is ` +
                            `${BREVITY_MAX_LINES} (~one screen). Keep this and following replies short — ` +
                            `answer or the single decision needed, then stop. No restated context, no ` +
                            `unpursued options, no re-explaining settled points. The user will ask if they want depth.`,
                    };
                }
            } catch (e) {
                await session.log(`brevity check skipped: ${e?.message ?? e}`);
            }
            return {};
        },
    },
    tools: [],
});
