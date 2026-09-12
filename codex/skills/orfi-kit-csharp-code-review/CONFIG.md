# Baseline C# config reference

A starting point for repos that have no config of their own, and a comparison point for repos that
do. **The repo under review always wins** — if it has its own `.editorconfig`, that is the contract,
and this file is only a reference. Never flag a violation of this baseline in a repo that has its
own rules.

**Where the repo encodes nothing, this baseline becomes the contract** — judge against it and report
deviation as a finding, citing the baseline key. It is not merely offered for adoption. The write-time
surfaces already hold authors to exactly that: the guardrails in `~/.codex/AGENTS.md` instruct them
to treat this baseline as the contract for a repo that encodes nothing and to report deviation as a
violation. A rule
enforced when code is written but ignored when it's reviewed is worse than no rule.

Say which standard you used — a review judged against this baseline and one judged against a repo's
own `.editorconfig` are different reviews, and the report's Sources line must name which. Only fall
through to the prevailing pattern of the surrounding code where *this baseline is also silent*.

## Where rules come from

Read these before making any style or naming call. `.editorconfig` resolves nearest-file-wins up the
tree until `root = true`, so read the one closest to each changed file.

| Source | What it decides |
|---|---|
| `.editorconfig` | Naming, formatting, using ordering |
| `Directory.Build.props` | `TreatWarningsAsErrors`, `EnforceCodeStyleInBuild`, `AnalysisLevel`, `Nullable`, `NoWarn` |
| `.globalconfig` | Severity overrides (does not cascade by directory) |
| `stylecop.json` + analyzer packages | `SA*`, Roslynator, Sonar rules. `SA1200` and `IDE0065` can disagree on using placement — note the conflict rather than picking a side |
| `*.csproj` / `*.ruleset` | Per-project `NoWarn` / `WarningsAsErrors` overrides |
| CI workflow | The command CI actually runs is the real definition of "conforms" |

Naming rules come as a triplet — `dotnet_naming_rule.*` + `dotnet_naming_symbols.*` +
`dotnet_naming_style.*`. Read all three before judging a name, and read `applicable_kinds`
literally: `field` covers `const` and `static readonly` too.

Two properties worth calling out: `EnforceCodeStyleInBuild` is load-bearing — without it, IDE00xx
style rules stay silent at build time no matter what `.editorconfig` says. And `TargetFramework`
is deliberately absent below; it is not a style rule and belongs to each repo.

## `.editorconfig`

```ini
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{csproj,props,targets,json,yml,yaml}]
indent_size = 2

[*.{ts,tsx,js,jsx,html,css}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.cs]
# Organize usings
dotnet_sort_system_directives_first = true
dotnet_separate_import_directive_groups = false

# Namespace
csharp_style_namespace_declarations = file_scoped:warning

# var preferences
csharp_style_var_for_built_in_types = true:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = true:suggestion

# Expression-bodied members
csharp_style_expression_bodied_methods = when_on_single_line:suggestion
csharp_style_expression_bodied_constructors = false:suggestion
csharp_style_expression_bodied_properties = true:suggestion

# Pattern matching
csharp_style_pattern_matching_over_is_with_cast_check = true:warning
csharp_style_pattern_matching_over_as_with_null_check = true:warning

# Null checking
csharp_style_throw_expression = true:suggestion
csharp_style_conditional_delegate_call = true:suggestion

# Code style
dotnet_style_object_initializer = true:suggestion
dotnet_style_collection_initializer = true:suggestion
dotnet_style_prefer_auto_properties = true:suggestion
dotnet_style_prefer_simplified_boolean_expressions = true:suggestion
dotnet_style_prefer_conditional_expression_over_assignment = true:suggestion

# Naming conventions
dotnet_naming_rule.private_fields_should_be_camel_case.severity = warning
dotnet_naming_rule.private_fields_should_be_camel_case.symbols = private_fields
dotnet_naming_rule.private_fields_should_be_camel_case.style = camel_case_with_underscore
dotnet_naming_symbols.private_fields.applicable_kinds = field
dotnet_naming_symbols.private_fields.applicable_accessibilities = private
dotnet_naming_style.camel_case_with_underscore.required_prefix = _
dotnet_naming_style.camel_case_with_underscore.capitalization = camel_case

dotnet_naming_rule.interfaces_should_begin_with_i.severity = warning
dotnet_naming_rule.interfaces_should_begin_with_i.symbols = interfaces
dotnet_naming_rule.interfaces_should_begin_with_i.style = begins_with_i
dotnet_naming_symbols.interfaces.applicable_kinds = interface
dotnet_naming_style.begins_with_i.required_prefix = I
dotnet_naming_style.begins_with_i.capitalization = pascal_case

dotnet_naming_rule.async_methods_should_end_with_async.severity = suggestion
dotnet_naming_rule.async_methods_should_end_with_async.symbols = async_methods
dotnet_naming_rule.async_methods_should_end_with_async.style = ends_with_async
dotnet_naming_symbols.async_methods.applicable_kinds = method
dotnet_naming_symbols.async_methods.required_modifiers = async
dotnet_naming_style.ends_with_async.required_suffix = Async
dotnet_naming_style.ends_with_async.capitalization = pascal_case
```

## `Directory.Build.props`

```xml
<Project>
  <PropertyGroup>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
</Project>
```
