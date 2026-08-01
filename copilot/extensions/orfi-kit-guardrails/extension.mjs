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

// --- Language conventions, injected at session start -------------------------
// Purpose: conventions used to be consulted only at review time, so code got
// written blind to the repo's own config and fixed afterwards — or shipped and
// caught by CI. Injecting them up front moves the rules to WRITE time.
//
// PLATFORM LIMIT — do not "fix" this by adding a verifier here. The Copilot SDK
// exposes only onSessionStart and onUserPromptSubmitted: there is no per-edit
// event and no post-response event, so this side can LOAD conventions but cannot
// VERIFY a file after it is written. Claude Code gets two extra PostToolUse
// hooks (orfi-kit-verify-{csharp,cpp}-format.sh) that have no equivalent here.
// This is the same asymmetry already documented above for brevity: Claude gates,
// Copilot nudges.
//
// AUTHORITY: the repo under review always wins. These blocks tell the model to go
// READ the repo's own .editorconfig / .clang-format / .clang-tidy — they do not
// restate a baseline, because a hardcoded rule here would outrank the repo's and
// that is exactly the failure the code-review CONFIG.md files forbid.
//
// Keep the RULE TEXT below in step with the Claude-side loaders
// (claude/hooks/orfi-kit-load-csharp-conventions.sh and
// orfi-kit-load-cpp-conventions.sh). The two are maintained separately because
// they run on different platforms and cannot share code — CHANGE THEM TOGETHER.
// The brevity DEPTH_REQUEST list drifted exactly this way once; don't repeat it.
const CSHARP_CONVENTIONS = `
[ORFI C# CONVENTIONS — WRITE-TIME, NOT REVIEW-TIME]
Before writing or editing any .cs file, read the rules this repo actually encodes and comply on the FIRST draft. Do not defer naming or formatting to review or CI.
1. Read the NEAREST .editorconfig (cascades nearest-file-wins up to root = true) and obey its [*.cs] section.
2. Read dotnet_naming_rule / dotnet_naming_symbols / dotnet_naming_style as COMPLETE TRIPLETS — a rule alone is meaningless without the symbols it selects and the style it applies.
3. Read applicable_kinds LITERALLY: 'field' COVERS const AND static readonly. A const IS a field, so a field rule (e.g. required_prefix = _) applies to it. Misreading this is a known cause of mass naming violations — a PascalCase private const has passed review and broken the build.
4. Read Directory.Build.props for TreatWarningsAsErrors, EnforceCodeStyleInBuild, and Nullable. If TreatWarningsAsErrors is true, a style or naming warning is a BUILD BREAK, not a nit.
5. If the repo encodes nothing, say so and follow the prevailing pattern of the surrounding file. Never substitute general C# habit for a rule the repo did not set.
`;

const CPP_CONVENTIONS = `
[ORFI C++ CONVENTIONS — WRITE-TIME, NOT REVIEW-TIME]
Before writing or editing any .cpp/.hpp/.h/.cc/.cxx/.inl file, read the rules this repo actually encodes and comply on the FIRST draft.
1. Read the NEAREST .clang-format (formatting, include order) and .clang-tidy (naming via readability-identifier-naming.*, static analysis). Both resolve nearest-file-wins up the directory tree.
2. clang-tidy is largely INERT without compile_commands.json — it cannot resolve includes. If there is no compilation database, the naming rules will NOT be mechanically enforced, so apply them by reading. Unverified is not the same as clean.
3. Most C++ repos ship NEITHER config. That is normal, not an error — follow the prevailing pattern of the file being edited and its immediate siblings, and say that is what you did. Never import an external C++ style guide.
4. If .clang-tidy enables cppcoreguidelines-owning-memory, the repo has encoded a smart-pointer ownership policy and raw owning pointers are a real violation. Otherwise do not treat raw pointers as defects.
5. No tool enforces FILENAMES — clang-tidy covers identifiers only. Treat filename conventions as advisory and never propose bulk renames: a rename breaks every #include of the old name.
`;

// Which block to inject. Detecting the language from the workspace keeps a C#-only
// repo from carrying C++ rules it will never use (and vice versa); a mixed repo
// gets both. Detection is best-effort and read-only — on any doubt we inject
// nothing rather than assert the wrong convention set.
async function detectConventions(cwd) {
    const blocks = [];
    try {
        const { readdir } = await import("node:fs/promises");
        const seen = { cs: false, cpp: false };
        const skip = new Set([
            "node_modules", ".git", "bin", "obj", "build", "out",
            "third_party", "external", "vendor", "packages",
        ]);
        // Bounded breadth-first walk: enough to classify a repo, cheap enough to
        // run on every session start. Never recurse the whole tree.
        const queue = [{ dir: cwd, depth: 0 }];
        const MAX_DEPTH = 3;
        let visited = 0;
        while (queue.length && visited < 400) {
            const { dir, depth } = queue.shift();
            visited++;
            let entries;
            try {
                entries = await readdir(dir, { withFileTypes: true });
            } catch { continue; }
            for (const e of entries) {
                const name = e.name;
                if (e.isDirectory()) {
                    if (depth < MAX_DEPTH && !skip.has(name) && !name.startsWith(".")) {
                        queue.push({ dir: `${dir}/${name}`, depth: depth + 1 });
                    }
                    continue;
                }
                if (/\.(cs|csproj|sln)$/i.test(name)) seen.cs = true;
                else if (/\.(cpp|hpp|cc|cxx|inl)$/i.test(name)) seen.cpp = true;
                else if (/^CMakeLists\.txt$/i.test(name) || /\.pro$/i.test(name)) seen.cpp = true;
                if (seen.cs && seen.cpp) break;
            }
            if (seen.cs && seen.cpp) break;
        }
        if (seen.cs) blocks.push(CSHARP_CONVENTIONS);
        if (seen.cpp) blocks.push(CPP_CONVENTIONS);
    } catch {
        // Detection failed. Inject nothing — guessing the wrong language would
        // assert conventions this repo never agreed to.
    }
    return blocks;
}

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
            // Language conventions ride along with the guardrails so they are in
            // context before the first edit, not after the review.
            let extra = [];
            try {
                extra = await detectConventions(process.cwd());
                if (extra.length) {
                    await session.log(`Orfi conventions injected (${extra.length} block(s))`);
                }
            } catch (e) {
                await session.log(`convention detection skipped: ${e?.message ?? e}`);
            }
            return { additionalContext: [GUARDRAILS, ...extra].join("\n") };
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
