# orfi-kit-cpp-code-review

> C++ review that runs the enforcing tools (`clang-format` / `clang-tidy` / build / tests) and grounds style verdicts in the repo's own config instead of general C++ norms.

## What it does

Reviews C++ changes in two lanes. The **tool lane** runs the enforcers — `clang-format --dry-run -Werror`, `clang-tidy`, the project's build, and its tests — and pastes their output rather than describing what they'd probably say. The **judgment lane** covers what no tool can see: correctness, memory and lifetime, const correctness, header hygiene, completeness, test coverage, and ADR/PRD conformance.

It's the C++ sibling of [`orfi-kit-csharp-code-review`](orfi-kit-csharp-code-review.md), built on the same principle after a misnamed member passed a C# review because the reviewer trusted language norms over the rule the repo had actually encoded. The two stay separate on purpose: the lesson generalizes, the toolchain doesn't.

**C++ makes the problem harder, not easier.** There's no single command covering format, style, and analysis, and most C++ repos ship no `.clang-format` and no `.clang-tidy` at all — so there's frequently no encoded rule to read. That's exactly when it's tempting to fall back on "what C++ usually looks like," which is the failure this skill exists to resist. With no config, it follows the prevailing pattern in the file being reviewed and says that's what it did.

## When it fires / how to invoke

User-invoked; it never runs on its own. Typically before opening a PR.

```
/orfi-kit-cpp-code-review
```

Optional scope argument: `DIFF` (default), `FULL` (whole project), or an explicit path.

## Prerequisites

- A C++ project. Everything else is optional and the review degrades to match.
- `clang-format` and a `.clang-format` file for the formatting lane.
- `clang-tidy`, a `.clang-tidy` file, **and** a `compile_commands.json` for the naming/analysis lane — without the compilation database `clang-tidy` can't resolve includes and its output is unreliable.
- The project's own build and test tooling (CMake/qmake/Ninja/MSBuild; CTest or whatever it uses).
- Optional: `orfi-kit-doxygen-docs` for the doc-comment check. On Claude Code, `/security-review` for the security item.
- Optional: a source of truth for intent. Nothing here is required — the review degrades gracefully and asks you when it finds nothing.

## Behavior / rules

- **Scope** — defaults to the diff against the parent branch, matching `*.cpp` / `*.h` / `*.hpp` / `*.cc` / `*.cxx` / `*.inl`. Asks which scope you want when the default is unusable, and always states the scope it settled on.
- **Excludes vendored and generated code** — `glm/`, `third_party/`, `external/`, `vendor/`, single-header libraries, and generated files (`ui_*.h`, `moc_*.cpp`, `qrc_*.cpp`). Those follow their upstream's conventions, so reviewing them is noise. It reports which paths it skipped.
- **Config first** — reads `.clang-format`, `.clang-tidy`, `compile_commands.json`, and `CMakeLists.txt` / `*.pro` before making any naming or formatting call. Both clang config files resolve nearest-file-wins up the tree, so it reads the one closest to each changed file. It expects them to be missing, which changes what it's entitled to assert rather than stopping the review.
- **Read-only on source** — never runs `clang-format -i`, and never reconfigures or rebuilds the project to generate a compilation database. Generating a build database is a build action, not a review action.
- **Uses the project's own commands** — reads the build files and any project instruction file for the generator, build directory, and flags rather than assuming. Whether `-Wall -Wextra -Werror` (or `/W4 /WX`) is set decides whether a warning is a finding or a nit.
- **Real test numbers** — reads the test summary line rather than trusting the exit code. If the project has no tests at all, it says so plainly: that's a material fact about the change's verifiability, not a defect in the diff.
- **Finds the source of truth before judging intent** — works down a ladder: `ONBOARDING.md` → a project instruction file (`CLAUDE.md` / `AGENTS.md`, which often documents the real build and test commands) → the session-state handoff → PRD or spec → ADRs → a plan in whatever shape the repo uses → PR body, commits, or linked ticket → tests as executable spec → public API contracts. **If it can't find any of them it asks you.**
- **Degrades rather than refuses** — with no source of truth it says "completeness unverifiable", names the strongest rung it did find, and reviews everything that doesn't need a spec. Missing tooling narrows the review the same way; it never blocks or errors because a tool or document was absent.
- **Correctness splits in two** — *internal* correctness needs no spec and always runs (edge cases, null and error paths, overflow, signed/unsigned mixing, uninitialized members, iterator invalidation, dangling references, use-after-move). *Intent* correctness requires a rung from the ladder, and the review names which one it judged against.
- **C++-specific judgment** — memory and lifetime (leaks on early-return and exception paths, double frees, use-after-free, dangling references, non-virtual destructors on polymorphic bases, rule of three/five/zero, unclear ownership), const correctness, and header hygiene (self-containment, include order, includes that should be forward declarations, guards present and matching).
- **Raw pointers are a style, not a defect** — manual `new`/`delete` and raw pointers are never findings in themselves; Qt's parent-child ownership is built on them. It flags the leak, not the technique, and won't suggest smart pointers as a stylistic upgrade — only where they'd fix a real lifetime bug, naming the bug. The baseline `.clang-tidy` deliberately omits `cppcoreguidelines-owning-memory`, `pro-bounds-*`, and the broad `modernize-*` set for the same reason.
- **Test coverage is reviewed, not assumed** — a green suite proves the existing tests pass, not that the new code is tested. It names changed paths with no covering test and won't claim a coverage percentage no tool produced.
- **Authority ladder for style findings** — every style finding names what it rests on: (1) repo config, citing the key or check name — the only rung that yields a real violation; (2) tool default in effect, citing the check name; (3) prevailing pattern, cited with `file:line` and reported as an unenforced convention, non-blocking; (4) nothing — stays silent. Rung 1 is usually empty in C++, so rung 3 does most of the work — and it prefers the pattern in the **file being changed** over a project-wide average, since C++ projects often mix styles across modules.
- **Large diffs fan out** — splits by file or by dimension (correctness, memory/lifetime, headers, completeness), passes the config it read into each pass, then consolidates and ranks once. On Claude Code this dispatches parallel subagents; on Copilot it's a deliberate sequential split.
- **Security is delegated, not reimplemented** — it records a verdict from a dedicated security review rather than improvising threat-modeling inline.

## Per-runtime differences

| | Claude Code | Copilot CLI |
| --- | --- | --- |
| Doc-comment check | invokes `/orfi-kit-doxygen-docs` | uses the `orfi-kit-doxygen-docs` skill |
| Security item | invokes `/security-review`; records `skipped (unavailable)` if absent | no bundled security-review skill — records `not run` and suggests a dedicated review before merge |
| Large diffs | dispatches parallel subagents (one per file or dimension), then consolidates | splits the pass deliberately by file or dimension, then consolidates |

## `CONFIG.md`

The skill ships a `CONFIG.md` alongside `SKILL.md`, installed with it. It lists where C++ rules come from and what each source decides, then provides a baseline `.clang-format` and `.clang-tidy`.

The baseline is a **seed to adopt, never a rule to enforce**. Where a repo has its own config, that config is the contract and the baseline is only a comparison point. This matters more in C++ than C#: since most repos have no clang config, a baseline treated as authority would effectively become "textbook norms with extra steps" — the original failure mode wearing a different hat.

The encoded conventions come from real Qt desktop projects: `PascalCase` types, `camelCase` functions and methods, `m_` private/protected members, `s_` statics, `snake_case` namespaces and filenames, `SCREAMING_SNAKE` constants and macros, 4-space indentation, `#ifndef` guards, and Doxygen `/** @brief */` blocks. Include order runs most-specific to least: related header → project → Qt → third-party → standard library → C system headers, with the self-header rule that a header only compiling because something preceded it is broken.

`readability-identifier-naming` is the load-bearing check — the C++ equivalent of the C# naming rule whose absence let a misnamed member through — and the baseline promotes it via `WarningsAsErrors` so it can't be ignored.

## Example

```
$ /orfi-kit-cpp-code-review

Scope: DIFF vs origin/master (base 9f8e7d6) — 3 changed files
       excluded: glm/ (vendored), ui_mainwindow.h (generated)
Config: none found (.clang-format, .clang-tidy both absent)
        CMakeLists.txt — C++17, no -Werror
Intent: CLAUDE.md → design/ADR.md (rung 5 of 9)

clang-format    not run (no .clang-format in repo)
clang-tidy      not run (no .clang-tidy, no compile_commands.json)
cmake --build   ok, 4 warnings (not fatal — no -Werror)
ctest           12 passed, 0 failed

BLOCKING
  1. src/exporter.cpp:88 — early return leaks the QPdfWriter allocated at :71.
     Exception path at :79 leaks it too. Use std::unique_ptr or give it a parent.
  2. src/exporter.h:23 — polymorphic base with public non-virtual destructor;
     deleting through a base pointer is undefined.

NITS
  3. src/exporter.h:31 — member named sourceModel, not m_sourceModel.
     Authority: prevailing pattern (unenforced — 9 of 10 members in this module
     use m_; no .clang-tidy to encode it). Consider adopting CONFIG.md's baseline.
  4. src/exporter.cpp:12 — <QFile> included before "exporter.h"; the related
     header should come first so it proves self-containment.

Verdict: 2 blocking findings. Style lane unconfirmed — no clang config in repo.
```

## Notes

- Pairs with `orfi-kit-doxygen-docs` (Doxygen comments) and `orfi-kit-csharp-code-review` (the C# sibling). The generic `orfi-kit-code-review` remains available for language-agnostic, whole-codebase reads.
- Self-contained: depends only on the C++ toolchain and, optionally, other orfi-kit skills. No dependency on any other kit.
