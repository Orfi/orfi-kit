# orfi-kit — global rules for OpenAI Codex

Installed to `~/.codex/AGENTS.md`. This is the declarative layer: the always-active guardrails and the write-time language conventions ride into every Codex session. Native mechanical enforcement for Codex lives in `~/.codex/hooks.json` — the sync guard (PreToolUse/Bash, deny) and the two format verifiers (PostToolUse, advisory) are wired there. The Stop contracts (brevity, skill-contract) and the convention loaders are deliberately NOT wired: Codex's transcript format is not a stable hook interface and plain stdout is ignored on Pre/PostToolUse, so wiring them would ship guardrails that always pass. Honest gaps over fake guardrails.

Keep this file in step with the Copilot extension runtime
(`copilot/extensions/orfi-kit-guardrails/extension.mjs`); they run on different platforms and cannot share code — CHANGE THEM TOGETHER.

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

[ORFI AUTHORITY ORDER]
When a code review must judge style or a naming choice, the authority is (1) the repo's own config always wins; (2) failing that, the kit's baseline in the code-review skills' CONFIG.md is the contract; (3) failing both, nothing is enforceable — follow the file's prevailing pattern. Never substitute a general convention guide for a rule nobody set.

[ORFI LANGUAGE CONVENTIONS — APPLY PER FILE TYPE]
Apply the C# block to .cs files, the C++ block to .cpp/.hpp/.h/.cc/.cxx/.inl files. Both blocks are below; ignore the one that does not apply to the file being handled.

[ORFI C# CONVENTIONS — WRITE-TIME, NOT REVIEW-TIME]
Before writing or editing any .cs file, read the rules this repo actually encodes and comply on the FIRST draft. Do not defer naming or formatting to review or CI.
1. Read the NEAREST .editorconfig (cascades nearest-file-wins up to root = true) and obey its [*.cs] section.
2. Read dotnet_naming_rule / dotnet_naming_symbols / dotnet_naming_style as COMPLETE TRIPLETS — a rule alone is meaningless without the symbols it selects and the style it applies.
3. Read applicable_kinds LITERALLY: 'field' COVERS const AND static readonly. A const IS a field, so a field rule (e.g. required_prefix = _) applies to it. Misreading this is a known cause of mass naming violations — a PascalCase private const has passed review and broken the build.
4. Read Directory.Build.props for TreatWarningsAsErrors, EnforceCodeStyleInBuild, and Nullable. If TreatWarningsAsErrors is true, a style or naming warning is a BUILD BREAK, not a nit.
5. If the repo encodes NOTHING (no .editorconfig, no Directory.Build.props), fall back to the orfi-kit baseline in the code-review skill's CONFIG.md (~/.agents/skills/orfi-kit-csharp-code-review/CONFIG.md) and treat it as the contract for this repo: read it and comply, and report deviation as a violation. Repo config still wins wherever it exists. If the baseline is not installed either, only then say nothing is enforceable and follow the prevailing pattern of the surrounding file. Never substitute general C# habit for a rule nobody set, and never write config into the repo.

[ORFI C++ CONVENTIONS — WRITE-TIME, NOT REVIEW-TIME]
Before writing or editing any .cpp/.hpp/.h/.cc/.cxx/.inl file, read the rules this repo actually encodes and comply on the FIRST draft.
1. Read the NEAREST .clang-format (formatting, include order) and .clang-tidy (naming via readability-identifier-naming.*, static analysis). Both resolve nearest-file-wins up the directory tree.
2. clang-tidy is largely INERT without compile_commands.json — it cannot resolve includes. If there is no compilation database, the naming rules will NOT be mechanically enforced, so apply them by reading. Unverified is not the same as clean.
3. Most C++ repos ship NEITHER config. That is normal, not an error — and it is when the orfi-kit baseline takes over: read the code-review skill's CONFIG.md (~/.agents/skills/orfi-kit-cpp-code-review/CONFIG.md) and treat it as the contract for this repo, reporting deviation as a violation. Repo config still wins wherever it exists. If the baseline is not installed either, only then follow the prevailing pattern of the file and its immediate siblings. Never import an external C++ style guide, and never write config into the repo.
4. If .clang-tidy enables cppcoreguidelines-owning-memory, the repo has encoded a smart-pointer ownership policy and raw owning pointers are a real violation. Otherwise do not treat raw pointers as defects.
5. No tool enforces FILENAMES — clang-tidy covers identifiers only. Treat filename conventions as advisory and never propose bulk renames: a rename breaks every #include of the old name.