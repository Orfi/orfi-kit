---
name: orfi-kit-doxygen-docs
description: "Enforce Doxygen documentation comments on C++ public, protected, and exposed declarations in header files. Trigger phrases: doxygen, doxygen docs, doxygen comments, missing documentation, document members, add comments, check doxygen docs, enforce docs, document this, add doxygen, @brief, header docs."
---

# orfi-kit-doxygen-docs — C++ Doxygen Documentation Enforcement

This skill is **always active**. It enforces Doxygen documentation on all exposed C++ declarations in header files — automatically, without being invoked, and without relying on the pre-commit hook.

C++ only. C#, TypeScript, and Python are covered by separate skills.

Doxygen reference: <https://www.doxygen.nl/> (v1.17.0). Tags may be written with either prefix — `@tag` or `\tag`; this skill uses `@tag`.

---

## The rule — absolute, no exceptions

Documentation is tied to the **API surface**, which in C++ means **declarations in header files**, keyed on *linkage*, not on file extension.

| Surface | Document? |
|---|---|
| `public:` members (in headers) | ✅ Always |
| `protected:` members (in headers) | ✅ Always |
| `static` members on exposed types (in headers) | ✅ Always |
| Free functions, classes/structs, enums, templates at namespace scope (in headers) | ✅ Always |
| `private:` members | ❌ Never |
| `.cpp` / `.cc` implementation files | ❌ Not scanned (API lives in headers) |

**A C++ task is not done until every changed exposed declaration in a header has a Doxygen block. No exceptions.**

---

## Autonomous enforcement (orchestrator role)

Do not wait to be asked. Do not wait for the hook. Apply these rules the moment any C++ header (`.h` / `.hpp` / `.hh` / `.hxx`) work is delegated or received:

1. **Before spawning a sub-agent**: inject the Doxygen doc rule into the agent prompt — it is a hard constraint, not a suggestion.
2. **After receiving C++ output**: run the check script immediately. Do not commit or proceed until it exits `0`.
3. **Block yourself** from marking a task complete if any violation remains.

---

## Orchestrator — reviewing C++ output from sub-agents

1. Run `pwsh scripts/check-doxygen-docs.ps1 -Changed` against all modified header files immediately upon receiving output.
2. If violations exist: stop, report them to the executor, demand fixes. Do not proceed.
3. Only commit when the check script exits `0`.

---

## Check script (repo tooling)

The repo ships `scripts/check-doxygen-docs.ps1` — a deterministic scanner that exits `1` on violations and `0` when clean. It scans header files only and is style-agnostic (accepts either `/** */` or `///`).

```powershell
# Scan staged files only (used by pre-commit hook)
pwsh scripts/check-doxygen-docs.ps1 -Staged

# Scan all changed files since last commit
pwsh scripts/check-doxygen-docs.ps1 -Changed

# Scan specific files
pwsh scripts/check-doxygen-docs.ps1 -Files @("include/customer/CustomerRecordRepository.hpp")
```

---

## Pre-commit hook

The repo ships `.githooks/pre-commit` — runs `-Staged` automatically on every `git commit`. Blocks the commit if violations are found, like a VSTS check-in policy.

**One-time setup per clone:**
```powershell
pwsh scripts/setup-hooks.ps1
```

This runs `git config core.hooksPath .githooks`. After setup, the hook fires automatically — no manual action needed.

**Bypass (exceptional cases only):**
```bash
git commit --no-verify
```

---

## Comment style — follow what's already there

Doxygen accepts multiple comment styles. This skill standardizes **per file** by following the convention already in use, rather than imposing one globally:

1. Before writing Doxygen in a file, **detect the existing style** — first within the current file, then in sibling files (same directory / the header's `.cpp` pair). **Follow it**, and **tell the user** which style was detected (e.g. "Following the `///` style already used in this header").
2. If **no existing Doxygen comments** exist to key off, **ask the user**: `/** */` or `///`. Recommend `/** */` (the most common C++ convention and the maintainer's stated preference).

The check script does **not** enforce style — it accepts either `/** */` or `///` as documented. Style consistency is this skill's job.

---

## The `.cpp` anti-pattern — never silently document an implementation file

Header-only scanning is correct-by-construction, not a shortcut. When editing a `.cpp` / `.cc`:

1. **`static` class members** are *declared* in the header (document there) and merely *defined* in the `.cpp`. Never re-document the definition.
2. **File-scope `static` / anonymous-namespace functions and globals** have **internal linkage** — implementation details, not API. Do **not** add `@brief`. Doxygen itself skips these by default (`EXTRACT_STATIC = NO`, `EXTRACT_ANON_NSPACES = NO`).
3. **A non-`static` free function or global defined only in a `.cpp` with no header declaration** has external linkage but no declared API surface — a code smell. If it is genuinely public, **tell the user to declare and document it in a header**, rather than silently adding `@brief` to the `.cpp` definition.

---

## Minimum tag set per member type

```cpp
/**
 * @brief Resolves a legacy record ID to its cache-backed mapping for the given tenant.
 *
 * @param tenantId The tenant slug (e.g. @c acme).
 * @param recordId The legacy record ID.
 * @return The resolved CustomerRecord, or @c std::nullopt if no mapping exists.
 * @throws CacheConnectionError when the cache backend is unavailable.
 */
std::optional<CustomerRecord> Find(std::string_view tenantId, std::string_view recordId);
```

| Member | Required tags |
|---|---|
| Function / method | `@brief` + `@param` per parameter + `@return` (non-void) + `@throws` (if it throws) |
| Class / struct / interface | `@brief` |
| Enum | `@brief` on the enum + `@brief` (or a trailing `///<`) on every enumerator |
| Constructor | `@brief` + `@param` per parameter |
| Template | `@tparam` per template parameter (plus the above) |
| Static member | Same as the non-static equivalent |

**Never** suppress Doxygen warnings instead of fixing the missing comment.

---

## Tag mapping — for users coming from xml-docs (C#)

| C# XML doc | Doxygen |
|---|---|
| `<summary>` | `@brief` |
| `<param name>` | `@param name` |
| `<returns>` | `@return` |
| `<exception>` | `@throws` |
| `<typeparam>` | `@tparam` |

---

## Style — formal API documentation, never personal or narrative

Doxygen comments are **reference documentation for the API surface**, read by other developers and by generated HTML/IDE tooltips. Write them as formal technical documentation, **not** as a personal narrative, a changelog, or a conversation.

**Voice and grammar:**
- Use the **third-person, present-tense, declarative** form describing *what the member does*. Briefs of functions conventionally begin with a verb: "Resolves…", "Validates…", "Builds…", "Gets…", "Constructs a new instance of…".
- **No first or second person.** Never "I", "we", "you", "let's", "our".
- State behaviour as fact about the code, not as a story about the work or the author's intent.

**Never include:**
- Narrative / conversational phrasing — e.g. "This function basically just grabs the key…", "Here we loop through and…", "Now we check the deny-list first".
- Personal commentary, opinions, or hedging — "I think", "probably", "hopefully", "for now", "TODO-ish", "a bit hacky".
- Work-history / changelog notes — "added in this PR", "as discussed", "per the ticket", "refactored from the old version". (Use git/issue tracker for history, not doc comments.)
- Planning / phase / story / ticket-process terminology of any kind — e.g. phase numbers, sprint names, or a story nickname. (Reference behaviour, or an issue key if a reference is genuinely needed.)
- Jokes, emoji, or filler ("the evt", "the ctx", "does stuff").

**Do / Don't:**

```cpp
// ❌ Narrative / personal — WRONG
/**
 * @brief Here we first check the deny-list (added in PROJ-123) and then, if we're good,
 * I look up the fingerprint. Basically returns null if anything's off.
 */

// ✅ Formal API documentation — RIGHT
/**
 * @brief Validates a modern API key by checking the cache deny-list, then resolving the
 * key fingerprint to its cached metadata. Returns @c std::nullopt for any revoked,
 * expired, unknown, or unverifiable key (fail-closed).
 */
```

Keep descriptions accurate and specific to the member's contract: inputs (`@param`), result (`@return`), and failure modes (`@throws`). Meaningful, not filler — but formal, not chatty.

---

## Exclusions — never flag these

- `private:` members
- `.cpp` / `.cc` implementation files (API lives in headers)
- Generated files: `*.generated.*`
- Build directories: `obj/`, `bin/`, `build/`
- Test files — test names are self-documenting; Doxygen comments are not required

---

## Quick-reference patterns

```cpp
// Interface (abstract base)
/// @brief Provides read access to customer record mappings stored in the cache.
class ICustomerRecordRepository { /* ... */ };

// Free function at namespace scope
/**
 * @brief Builds the primary cache key for a customer record mapping.
 * @param tenantId The tenant slug.
 * @param recordId The legacy record ID.
 * @return The formatted cache key string.
 */
std::string BuildKey(std::string_view tenantId, std::string_view recordId);

// Enum (each enumerator documented with trailing ///<)
/// @brief Identifies the type of a document.
enum class DocumentType {
    Procedure,  ///< A procedure document with ordered steps.
    Article     ///< An article document with free-form content.
};

// Template
/**
 * @brief Caches the most recently resolved value for a key.
 * @tparam TKey   The key type used for lookups.
 * @tparam TValue The cached value type.
 */
template <typename TKey, typename TValue>
class ResolutionCache { /* ... */ };

// Constructor
/**
 * @brief Constructs a new repository with the required cache connection.
 * @param cache The cache connection handle.
 */
explicit CustomerRecordRepository(CacheConnection& cache);
```

---

## CI integration (future)

The check script is CI-ready by design (`exit 0` / `exit 1`). It is the CI backstop; the always-active skill is the real enforcer. Wiring the script into GitHub Actions to block PRs is tracked as a separate task.

---

## References

- [Doxygen Manual — documenting the code](https://www.doxygen.nl/manual/docblocks.html)
- [Doxygen — special commands](https://www.doxygen.nl/manual/commands.html)
- [Doxygen — configuration (`EXTRACT_STATIC`, `EXTRACT_ANON_NSPACES`)](https://www.doxygen.nl/manual/config.html)
- [Doxygen homepage](https://www.doxygen.nl/)
