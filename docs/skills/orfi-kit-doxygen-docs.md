# orfi-kit-doxygen-docs

> Always-on enforcement of Doxygen documentation comments on every public, protected, and static C++ declaration in header files.

## What it does

This skill enforces formal Doxygen documentation on all exposed C++ declarations — public members, protected members, static members on exposed types, and free functions, classes, structs, enums, and templates at namespace scope. It is always active: it applies automatically the moment any C++ file is opened for writing, without you invoking it and without relying on the pre-commit hook. A C++ task is not considered done until every changed exposed declaration in a header carries a Doxygen block. Enforcement is scoped to **header files only** — the API surface lives in headers. C++ only — C#, TypeScript, and Python are covered by separate skills.

## When it fires / how to invoke

Always active. It auto-applies whenever a C++ file is written or edited. You can also nudge it explicitly with trigger phrases such as "doxygen docs", "add doxygen docs", "document declarations", "check doxygen docs", or "enforce docs".

## Prerequisites

- A C++ project (the skill is C++-only).
- Doxygen (<https://www.doxygen.nl/>, current version 1.17.0) to actually generate documentation — optional; the skill and checker do not require it to be installed.
- PowerShell (`pwsh`) or bash to run the presence checker (`scripts/check-doxygen-docs.ps1` / `scripts/check-doxygen-docs.sh`).

## Behavior / rules

Documentation requirement by surface — keyed on **linkage**, not file extension:

| Surface | Document? |
|---|---|
| `public:` members (in headers) | Always |
| `protected:` members (in headers) | Always |
| `static` members on exposed types (declared in headers) | Always |
| Free functions, classes/structs, enums, templates at namespace scope (in headers) | Always |
| `private:` members | Never |
| `.cpp`/`.cc` implementation files | Not scanned (API lives in headers) |

Comment-style policy — the skill standardizes per-file by **following what's already there**, rather than imposing one style globally:

1. Before writing Doxygen in a file, **detect the existing style** — first within the current file, then in sibling files (same directory, or the header's `.cpp` pair). **Follow it**, and **notify you** which style was detected (e.g. "Following the `///` style already used in this header").
2. If **no existing Doxygen comments** exist to key off, **ask you**: `/** */` or `///`. The recommended default is `/** */` (the most common C++ convention).

The `.cpp` anti-pattern: header-only scanning is correct-by-construction, not a shortcut. File-scope `static` functions and anonymous-namespace symbols in a `.cpp` have **internal linkage** — they are implementation details, not API, and need no `@brief`. But a non-`static` free function or global defined only in a `.cpp` with **no header declaration** is a code smell: external linkage with no declared API surface. When editing a `.cpp` and a genuinely-exposed symbol has no header declaration, the skill tells you to declare and document it in a **header** rather than silently adding `@brief` to the `.cpp` definition.

Autonomous enforcement steps applied to any C++ file opened for writing:

1. Write the Doxygen comment **before** the declaration, never after.
2. After writing, run `pwsh scripts/check-doxygen-docs.ps1 -Changed` (or the bash twin) and fix every violation before proceeding.
3. Block task completion if any violation remains.

Required tag set per declaration type (tag prefix is `@tag`, or `\tag`):

| Member | Required tags |
|---|---|
| Function / method | `@brief` + `@param` per parameter + `@return` (non-void) + `@throws` (if it throws) |
| Class / struct / interface | `@brief` |
| Enum | `@brief` on the enum + `@brief` (or a trailing `///<`) on every enumerator |
| Constructor | `@brief` + `@param` per parameter |
| Template | `@tparam` per template parameter (plus the above) |
| Static member | Same as the non-static equivalent |

Tag mapping reference (for users coming from the C# xml-docs sibling):

| C# XML doc | Doxygen |
|---|---|
| `<summary>` | `@brief` |
| `<param name>` | `@param name` |
| `<returns>` | `@return` |
| `<exception>` | `@throws` |
| `<typeparam>` | `@tparam` |

Never suppress Doxygen warnings instead of fixing the missing comment.

Style rules — write formal API reference documentation, not narrative:

- Third-person, present-tense, declarative. Function briefs begin with a verb ("Resolves…", "Validates…", "Gets…", "Initializes a new instance of…").
- No first or second person ("I", "we", "you", "let's", "our").
- Never include narrative/conversational phrasing, personal commentary or hedging ("I think", "probably", "for now", "a bit hacky"), work-history/changelog notes ("added in this PR", "as discussed"), planning/phase/story/ticket-process terminology, or jokes/emoji/filler. An issue key is acceptable only if a reference is genuinely needed.

Exclusions — never flag these:

- `private:` members
- Generated files: `*.generated.*`
- Build directories: `obj/`, `bin/`, `build/`
- Test files

Orchestrator / review role: scan every modified header for declarations missing a Doxygen block before committing; if violations exist, stop, report, and demand fixes; only commit when the check script exits `0`.

## Example

```cpp
/**
 * @brief Resolves a legacy record ID to its Redis-backed mapping for the given tenant.
 *
 * @param tenantId The tenant slug (e.g., @c acme).
 * @param recordId The legacy record ID.
 * @return Pointer to the resolved CustomerRecord, or @c nullptr if no mapping exists.
 * @throws RedisConnectionException Thrown when the Redis connection is unavailable.
 */
CustomerRecord* Find(const std::string& tenantId, const std::string& recordId);
```

## The check script

orfi-kit ships the checker the skill runs, in two forms — run either manually or from CI. This checker is C++/Doxygen-specific:

- `scripts/check-doxygen-docs.ps1` (PowerShell)
- `scripts/check-doxygen-docs.sh` (Linux/bash port — behavioural twin)

Both scan **header files only** (`.h` / `.hpp` / `.hh` / `.hxx`) and skip `.cpp` / `.cc` (linkage-correct: the API surface lives in headers). They are **presence-only**: a check flags an exposed declaration with **no** Doxygen block above it, accepting **either** a preceding `/** */` block **or** `///` lines as documented (the skill, not the script, enforces style consistency). The checker is **access-aware** — it tracks `public:` / `protected:` / `private:` section labels within a class or struct, requiring docs in public/protected sections and skipping private; namespace-scope declarations default to documentable. It walks backward past attributes (`[[...]]`), blank lines, and preprocessor lines to find the comment.

Both take the same modes and exit `0` (clean) / `1` (violations found):

```bash
scripts/check-doxygen-docs.sh --changed                 # .h* changed since HEAD + staged
scripts/check-doxygen-docs.sh --staged                  # .h* staged in git
scripts/check-doxygen-docs.sh --files include/Foo.hpp   # explicit file list
# PowerShell equivalent:
pwsh scripts/check-doxygen-docs.ps1 -Changed
```

Exclusions: `obj/`, `bin/`, `build/` path segments and `*.generated.*` filename globs are skipped. Output is `file:line` plus the offending declaration and a fix hint pointing at the `/orfi-kit-doxygen-docs` skill.

Copy the script into your C++ project's `scripts/` directory (orfi-kit does not auto-place it — it's project tooling, not a user-global skill).

Honest limitation: C++ access-section tracking in regex is harder than C#'s per-member access modifiers. The script is good-enough for CI — it catches undocumented public/protected members in normal headers — but does not perfectly parse pathological cases (deeply nested classes, macro-obscured declarations, heavy template metaprogramming). The always-active skill is the real enforcer; the script is the CI backstop.

## Notes

- This is the C++ sibling of [orfi-kit-xml-docs](orfi-kit-xml-docs.md), which enforces `///` XML documentation on C# members. The two share the same tag discipline, style/voice rules, presence-only checker shape, and `--staged` / `--changed` / `--files` modes with `0`/`1` exit codes.
- The check script exits `0`/`1` and is CI-ready; wiring it to GitHub Actions is tracked separately.
- See the [Doxygen documentation](https://www.doxygen.nl/) for the full set of special commands and configuration options.
