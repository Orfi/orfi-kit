# Baseline C++ config reference

A starting point for repos that have no config of their own, and a comparison point for repos that
do. **The repo under review always wins** — if it has its own `.clang-format` or `.clang-tidy`, that
is the contract and this file is only a reference. Never flag a violation of this baseline in a repo
that has its own rules.

Expect to need this file. Unlike C#, where `.editorconfig` is near-universal, most C++ repos ship no
`.clang-format` or `.clang-tidy` at all — so "no encoded rule" is the normal case, not the exception.
When that's true, fall back to the prevailing pattern in the file you're reviewing and offer this
baseline as something to adopt.

## Where rules come from

| Source | What it decides |
|---|---|
| `.clang-format` | Formatting: indentation, braces, column limit, include ordering and grouping |
| `.clang-tidy` | Naming (`readability-identifier-naming`), static analysis, modernization, which checks are errors |
| `compile_commands.json` | The compilation database `clang-tidy` needs to resolve includes. Without it, `clang-tidy` is largely inert — CMake emits it via `CMAKE_EXPORT_COMPILE_COMMANDS=ON`; qmake needs a wrapper such as `bear` |
| `CMakeLists.txt` / `*.pro` | Language standard, warning flags, `-Werror`, target layout, test registration |
| `.editorconfig` | Indentation and whitespace where present; `clang-format` takes precedence for C++ |
| Compiler flags | `-Wall -Wextra -Werror` (or `/W4 /WX`) decide whether a warning is a build failure |
| CI workflow | The command CI actually runs is the real definition of "conforms" |

`clang-tidy` naming is configured through `readability-identifier-naming.*` keys — one pair per
symbol kind (`*Case` plus optional `*Prefix`/`*Suffix`). Read the specific keys before judging a
name; a missing key means that symbol kind is simply unchecked.

## Conventions this baseline encodes

Derived from the reference projects, which are Qt desktop applications. **Treat them as one team's
choices, not as C++ law** — naming, ownership style, and formatting all vary legitimately between
projects, companies, and domains. Another repo's different answer is not a violation; it's that
repo's contract, and it wins:

| Symbol | Style | Example |
|---|---|---|
| Classes, structs, enums, type aliases | `PascalCase` | `MathOperation`, `VocabManager` |
| Functions and methods | `camelCase` | `getFloatPortNode`, `wordModel` |
| Private / protected members | `m_` + `camelCase` | `m_floatBulletInsertPoint`, `m_sourceModel` |
| Static class members | `s_` + `camelCase` | `s_instanceCount` |
| Local variables, parameters | `camelCase` | `errorMessage` |
| Namespaces, file names | `snake_case` | `math_operation.h` |
| Constants | `SCREAMING_SNAKE` | `BULLET_WIDTH`, `PEN_WIDTH` |
| Macros | `SCREAMING_SNAKE` | `QT_DEPRECATED_WARNINGS` |

Also standard in these projects: 4-space indentation, `#ifndef` include guards (not `#pragma once`),
Doxygen `/** @brief ... */` blocks on public and protected declarations, and file-local constants in
an anonymous namespace rather than as `static` globals.

## Include order

Most specific to least specific, so every header proves it is self-contained:

1. **Related header** — `user_processor.h` from `user_processor.cpp`
2. **Project headers** — other headers from this project
3. **Qt framework headers** — `<QString>`, `<QObject>`
4. **Third-party libraries**
5. **Standard library** — `<vector>`, `<memory>`
6. **C system headers**

**The self-header rule:** if a header only compiles because `<vector>` was included before it, that
header is broken. Reviewing this needs no tooling — read the header's own includes against what it
uses.

## `.clang-format`

```yaml
---
Language: Cpp
BasedOnStyle: LLVM

IndentWidth: 4
TabWidth: 4
UseTab: Never
ColumnLimit: 120

AccessModifierOffset: -4
BreakBeforeBraces: Allman
AllowShortFunctionsOnASingleLine: Inline
AllowShortIfStatementsOnASingleLine: false
AllowShortLoopsOnASingleLine: false
PointerAlignment: Left
SpaceAfterCStyleCast: true
AlwaysBreakTemplateDeclarations: Yes
FixNamespaceComments: true
SortUsingDeclarations: true

# Include order mirrors the hierarchy above. Lower Priority sorts first.
SortIncludes: CaseSensitive
IncludeBlocks: Preserve
IncludeCategories:
  # Qt framework headers
  - Regex: '^<Q[A-Za-z]+>$'
    Priority: 3
  - Regex: '^<Qt[A-Za-z/]*>$'
    Priority: 3
  # C system headers
  - Regex: '^<(sys|linux|windows|unistd|fcntl)[A-Za-z/._]*\.h>$'
    Priority: 6
  # C++ standard library (no extension)
  - Regex: '^<[a-z_]+>$'
    Priority: 5
  # Remaining angle includes — third-party
  - Regex: '^<.*>$'
    Priority: 4
  # Project headers
  - Regex: '^".*"$'
    Priority: 2
IncludeIsMainRegex: '$'
---
```

`IncludeBlocks: Preserve` keeps the blank-line grouping these projects already use rather than
collapsing the tiers into one block. The related header sorts to Priority 1 automatically via
`IncludeIsMainRegex`.

## `.clang-tidy`

```yaml
---
Checks: >
  -*,
  bugprone-*,
  clang-analyzer-*,
  cppcoreguidelines-init-variables,
  cppcoreguidelines-pro-type-member-init,
  misc-*,
  modernize-use-nullptr,
  modernize-use-override,
  modernize-use-using,
  performance-*,
  readability-identifier-naming,
  readability-misleading-indentation,
  readability-redundant-*,
  -bugprone-easily-swappable-parameters,
  -misc-non-private-member-variables-in-classes,
  -readability-function-cognitive-complexity

WarningsAsErrors: 'readability-identifier-naming,bugprone-*'
HeaderFilterRegex: '.*'
FormatStyle: file

CheckOptions:
  - key: readability-identifier-naming.ClassCase
    value: CamelCase
  - key: readability-identifier-naming.StructCase
    value: CamelCase
  - key: readability-identifier-naming.EnumCase
    value: CamelCase
  - key: readability-identifier-naming.TypeAliasCase
    value: CamelCase
  - key: readability-identifier-naming.TypedefCase
    value: CamelCase
  - key: readability-identifier-naming.FunctionCase
    value: camelBack
  - key: readability-identifier-naming.MethodCase
    value: camelBack
  - key: readability-identifier-naming.PrivateMemberCase
    value: camelBack
  - key: readability-identifier-naming.PrivateMemberPrefix
    value: 'm_'
  - key: readability-identifier-naming.ProtectedMemberCase
    value: camelBack
  - key: readability-identifier-naming.ProtectedMemberPrefix
    value: 'm_'
  - key: readability-identifier-naming.ClassMemberCase
    value: camelBack
  - key: readability-identifier-naming.ClassMemberPrefix
    value: 's_'
  - key: readability-identifier-naming.VariableCase
    value: camelBack
  - key: readability-identifier-naming.ParameterCase
    value: camelBack
  - key: readability-identifier-naming.NamespaceCase
    value: lower_case
  - key: readability-identifier-naming.ConstantCase
    value: UPPER_CASE
  - key: readability-identifier-naming.ConstantMemberCase
    value: UPPER_CASE
  - key: readability-identifier-naming.EnumConstantCase
    value: UPPER_CASE
  - key: readability-identifier-naming.MacroDefinitionCase
    value: UPPER_CASE
---
```

`readability-identifier-naming` is the check that matters most: it is the C++ equivalent of the C#
naming rule whose absence lets a misnamed member pass review. `WarningsAsErrors` promotes it to a
failure so it cannot be ignored, the same role `TreatWarningsAsErrors` plays on the C# side.

The naming values below are this baseline's opinion, not a standard. `m_`/`s_` prefixes, `camelBack`
methods, and `UPPER_CASE` constants are common but far from universal — plenty of good C++ uses
`snake_case` methods, trailing `_` members, or `kPascalCase` constants. If the repo under review
disagrees, the repo is right.

Notes on what's in and out. `misc-non-private-member-variables-in-classes` is disabled because Qt
classes routinely expose public data members. `ConstantCase: UPPER_CASE` matches what these projects
do (`BULLET_WIDTH`, `YAW`) rather than the `kPascalCase` some style guides prefer — if a repo uses
`kConstant`, that repo wins.

Deliberately **not** enabled: `cppcoreguidelines-owning-memory`, `cppcoreguidelines-pro-bounds-*`,
`cppcoreguidelines-pro-type-reinterpret-cast`, and the broader `modernize-*` set. These flag raw
pointers, manual `new`/`delete`, pointer arithmetic, and C-style casts as violations on principle.
That's a legitimate style choice, not a defect — and Qt's parent-child ownership model is built on
raw pointers, so enabling them would bury real findings under thousands of stylistic ones. The two
`cppcoreguidelines-*` checks that are enabled catch uninitialized reads, which are genuine bugs.
Real lifetime defects — leaks, double frees, use-after-free — are caught by `clang-analyzer-*` and
`bugprone-*`, which are enabled.

## Enabling `clang-tidy` at all

`clang-tidy` needs a compilation database. For CMake:

```bash
cmake -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

For qmake, wrap the build (`bear -- make`) or generate one with `compiledb`. Generating a build
database is a **build** action, not a review action — if none exists, say so and fall back to reading
the code rather than mutating the project to enable a tool.

## Memory ownership is a project decision

This baseline takes no position on raw pointers versus smart pointers, because the right answer is
per-project: embedded and game code often keeps raw pointers deliberately, a modern service codebase
may mandate smart pointers, and Qt sits in between since its parent-child ownership is built on raw
pointers. The `.clang-tidy` above therefore omits `cppcoreguidelines-owning-memory`.

The skill resolves the mode per review — from the repo's `.clang-tidy`, then a written project or org
convention, then an explicit `RAW` / `SMART` argument, then the prevailing pattern, and finally by
asking. Genuine lifetime defects (leaks, double frees, use-after-free, dangling references,
non-virtual destructors on polymorphic bases) are findings in **every** mode; the mode only decides
whether raw ownership itself is worth mentioning, and when it is, it's a non-blocking nit.

If your project *has* decided, encode it — either enable `cppcoreguidelines-owning-memory` in
`.clang-tidy` or state the policy in an ADR or project instruction file. An encoded rule beats a
per-review question every time.
