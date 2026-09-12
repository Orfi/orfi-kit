#!/usr/bin/env pwsh
#
# orfi-kit installer (PowerShell) — the cross-platform twin of install.sh.
# Runs on Windows PowerShell 5+, and pwsh on Windows / macOS / Linux.
#
# orfi-kit is skills/markdown, seven enforcement hooks, an OpenCode plugin, a Copilot
# extension, and a Codex hooks.json + AGENTS.md. The SAME seven bash hooks power all
# four runtimes: Claude Code via ~/.claude/settings.json, GitHub Copilot CLI via a
# hooks registration file (~/.copilot/hooks/orfi-kit.json), OpenAI Codex CLI via
# ~/.codex/hooks.json, and OpenCode via a plugin that shells to the same scripts.
# This script is install-time plumbing only.
#
# Usage:
#   ./install.ps1                 interactive: asks which runtime(s) to install for
#   ./install.ps1 -Link           symlink instead of copy (dev: repo edits go live)
#   ./install.ps1 -Uninstall      remove an existing orfi-kit install
#   ./install.ps1 -Help           show this help
#
# Claude Code + OpenCode share one skill source (claude/skills) and the 10
# command files. Copilot uses its own source (copilot/skills) and its own home
# (~/.copilot/skills). Codex uses its own source (codex/skills) and its own home
# (~/.agents/skills). Hooks (bash scripts) get ONE shared home, ~/.claude/hooks,
# that serves Claude Code's settings.json, the Copilot + Codex hooks JSON, and the
# OpenCode plugin. On Windows those hooks invoke the scripts through Git Bash, so
# a Git Bash installation is required.

[CmdletBinding()]
param(
    [switch]$Link,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- paths -------------------------------------------------------------------

$RepoDir          = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc        = Join-Path $RepoDir 'claude/skills'
$CopilotSkillsSrc = Join-Path $RepoDir 'copilot/skills'
$CodexSkillsSrc   = Join-Path $RepoDir 'codex/skills'
$CmdsSrc          = Join-Path $RepoDir 'claude/commands'
$HookSrc          = Join-Path $RepoDir 'claude/hooks/orfi-kit-enforce-sync.sh'
$BrevitySrc       = Join-Path $RepoDir 'claude/hooks/orfi-kit-enforce-brevity.sh'
$ContractSrc      = Join-Path $RepoDir 'claude/hooks/orfi-kit-verify-skill-contract.sh'
$ExtSrc           = Join-Path $RepoDir 'copilot/extensions/orfi-kit-guardrails'
$CopilotHooksSrc  = Join-Path $RepoDir 'copilot/hooks'          # Copilot CLI hooks registration (JSON)
$CodexHooksJsonSrc = Join-Path $RepoDir 'codex/hooks.json'      # Codex native hooks registration (JSON)
$CodexAgentsSrc   = Join-Path $RepoDir 'codex/AGENTS.md'        # Codex global rules (markdown)
$OpencodePluginsSrc = Join-Path $RepoDir 'opencode/plugins'     # OpenCode hook plugin (TypeScript)
$ScriptsSrc       = Join-Path $RepoDir 'scripts'

$Home_     = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $Home_ '.config' }

$ClaudeSkills   = Join-Path $Home_ '.claude/skills'
$ClaudeCmds     = Join-Path $Home_ '.claude/commands'
$ClaudeHooks    = Join-Path $Home_ '.claude/hooks'
$ClaudeSettings = Join-Path $Home_ '.claude/settings.json'
$OpencodeSkills = Join-Path $XdgConfig 'opencode/skills'
$OpencodeCmds   = Join-Path $XdgConfig 'opencode/commands'
$CopilotSkills  = Join-Path $Home_ '.copilot/skills'
$CopilotExts    = Join-Path $Home_ '.copilot/extensions'   # verified from Copilot CLI bundle
$ClaudeScripts   = Join-Path $Home_ '.claude/scripts'
$OpencodeScripts = Join-Path $XdgConfig 'opencode/scripts'
$CopilotScripts  = Join-Path $Home_ '.copilot/scripts'
$CopilotHooks    = Join-Path $Home_ '.copilot/hooks'          # Copilot CLI hooks registration
$CodexSkills     = Join-Path $Home_ '.agents/skills'          # Codex user-scope skill home
$CodexHooksJson  = Join-Path $Home_ '.codex/hooks.json'       # Codex native hooks registration
$CodexAgents     = Join-Path $Home_ '.codex/AGENTS.md'        # Codex global rules (read first)
$OpencodePlugins = Join-Path $XdgConfig 'opencode/plugins'    # OpenCode plugin transport

# The doc-presence checkers + their git-hook wiring (scripts/). Both language
# pairs install for every runtime, since a repo may be C#, C++, or both.
#
# These are PROJECT tooling, unlike everything else here: the skills call them by
# the relative path scripts/check-*, which resolves against the reviewed repo's
# own cwd. Installing them user-globally is a FALLBACK for a repo that has no
# copy of its own — the project's copy still wins, exactly like the config
# authority ladder. Copying one into a project remains the better answer, because
# only then can that project's CI run it.
$ScriptNames = @(
  'check-xml-docs.ps1','check-xml-docs.sh',
  'check-doxygen-docs.ps1','check-doxygen-docs.sh',
  'setup-hooks.ps1','setup-hooks.sh'
)

$HookDest = Join-Path $ClaudeHooks 'orfi-kit-enforce-sync.sh'
$HookCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-enforce-sync.sh"'

$BrevityDest = Join-Path $ClaudeHooks 'orfi-kit-enforce-brevity.sh'
$BrevityCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh"'

# Skill-contract Stop hook. Blocks a skill's final report when a step the skill
# mandates has no tool_use record in the session transcript. Contracts live in
# CONTRACT.conf beside each SKILL.md and ship with the skill directory, so rules
# and prose cannot drift apart.
#
# Wired for Claude Code via settings.json Stop AND for Copilot via the Stop event
# in copilot/hooks/orfi-kit.json (transcript_path from the Stop payload; Copilot
# forces a correction turn with the reason).
$ContractDest = Join-Path $ClaudeHooks 'orfi-kit-verify-skill-contract.sh'
$ContractCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-verify-skill-contract.sh"'

# Convention hooks: two PreToolUse loaders that surface the repo's own rules
# BEFORE a file is written, and two PostToolUse verifiers that check the file
# after. Claude Code wires all four through settings.json; Copilot wires the
# verifiers (advisory — PostToolUse has no block semantics) through
# orfi-kit.json, and extension.mjs still loads conventions at session start as a
# first pass.
#
# Matchers are TOOL names (Write|Edit|MultiEdit), never file globs — the *.cs and
# C++ extension filtering happens inside each hook, from .tool_input.file_path.
$ConvMatcher = 'Write|Edit|MultiEdit'
$ConvPreHooks = @(
    'orfi-kit-load-csharp-conventions.sh'
    'orfi-kit-load-cpp-conventions.sh'
)
$ConvPostHooks = @(
    'orfi-kit-verify-csharp-format.sh'
    'orfi-kit-verify-cpp-format.sh'
)
$ConvHookNames = $ConvPreHooks + $ConvPostHooks

$ClaudeSkillNames = @('orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-scrum-poker','orfi-kit-xml-docs','orfi-kit-doxygen-docs','orfi-kit-csharp-code-review','orfi-kit-cpp-code-review')

$CopilotSkillNames = @(
  'orfi-kit-cleanup-state','orfi-kit-code-review','orfi-kit-commit','orfi-kit-cpp-code-review',
  'orfi-kit-csharp-code-review','orfi-kit-enforce-guardrails',
  'orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-init','orfi-kit-load-state',
  'orfi-kit-persist-state','orfi-kit-run-codegraph-phase',
  'orfi-kit-run-integration-tests-phase','orfi-kit-run-unit-tests-phase',
  'orfi-kit-scrum-poker','orfi-kit-set-helper-files-root','orfi-kit-standup',
  'orfi-kit-sync-branch','orfi-kit-sync-master','orfi-kit-xml-docs','orfi-kit-doxygen-docs'
)

# The 21 Codex skill dirs (same parity set as Copilot, adapted for Codex).
$CodexSkillNames = @(
  'orfi-kit-cleanup-state','orfi-kit-code-review','orfi-kit-commit','orfi-kit-cpp-code-review',
  'orfi-kit-csharp-code-review','orfi-kit-enforce-guardrails',
  'orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-init','orfi-kit-load-state',
  'orfi-kit-persist-state','orfi-kit-run-codegraph-phase',
  'orfi-kit-run-integration-tests-phase','orfi-kit-run-unit-tests-phase',
  'orfi-kit-scrum-poker','orfi-kit-set-helper-files-root','orfi-kit-standup',
  'orfi-kit-sync-branch','orfi-kit-sync-master','orfi-kit-xml-docs','orfi-kit-doxygen-docs'
)

# 14 command files — per-capability docs live in docs/skills/ (repo docs, not runtime).
$CommandNames = @(
  'orfi-kit-cleanup-state','orfi-kit-code-review','orfi-kit-commit','orfi-kit-enforce-guardrails',
  'orfi-kit-init','orfi-kit-load-state','orfi-kit-persist-state','orfi-kit-run-codegraph-phase',
  'orfi-kit-run-integration-tests-phase','orfi-kit-run-unit-tests-phase',
  'orfi-kit-set-helper-files-root','orfi-kit-standup','orfi-kit-sync-branch','orfi-kit-sync-master'
)

# The 7 shared enforcement hooks. All three runtimes shell to these scripts:
# Claude Code via settings.json, Copilot via copilot/hooks/orfi-kit.json, OpenCode
# via the plugin. Used to guarantee the scripts exist under ~/.claude/hooks even
# when Claude Code is not part of the install.
$AllHookNames = @(
  'orfi-kit-enforce-sync.sh',
  'orfi-kit-enforce-brevity.sh',
  'orfi-kit-verify-skill-contract.sh',
  'orfi-kit-load-csharp-conventions.sh',
  'orfi-kit-load-cpp-conventions.sh',
  'orfi-kit-verify-csharp-format.sh',
  'orfi-kit-verify-cpp-format.sh'
)

# --- helpers -----------------------------------------------------------------

function Say($msg) { Write-Host $msg }
function Die($msg) { Write-Error "error: $msg"; exit 1 }

function Show-Usage {
    Get-Content $MyInvocation.PSCommandPath | Select-Object -Skip 2 -First 17 |
        ForEach-Object { $_ -replace '^#$','' -replace '^# ','' }
    exit 0
}

function Place($src, $dest) {
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    if ($Link) {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
        Say "  linked  $dest"
    } else {
        Copy-Item -Recurse -Force $src $dest
        Say "  copied  $dest"
    }
}

function Install-ClaudeSkillsTo($targetDir) {
    foreach ($s in $ClaudeSkillNames) { Place (Join-Path $SkillsSrc $s) (Join-Path $targetDir $s) }
}
function Remove-ClaudeSkillsFrom($targetDir) {
    foreach ($s in $ClaudeSkillNames) {
        $p = Join-Path $targetDir $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}
function Install-CommandsTo($targetDir) {
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
    foreach ($c in $CommandNames) { Place (Join-Path $CmdsSrc "$c.md") (Join-Path $targetDir "$c.md") }
}
function Remove-CommandsFrom($targetDir) {
    foreach ($c in $CommandNames) {
        $p = Join-Path $targetDir "$c.md"
        if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
    }
}
function Install-ScriptsTo($targetDir) {
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
    foreach ($s in $ScriptNames) {
        Place (Join-Path $ScriptsSrc $s) (Join-Path $targetDir $s)
        # The .sh twins need the executable bit on POSIX; a no-op on Windows.
        if ($s -like '*.sh' -and ($IsLinux -or $IsMacOS)) {
            chmod +x (Join-Path $targetDir $s) 2>$null
        }
    }
}
function Remove-ScriptsFrom($targetDir) {
    foreach ($s in $ScriptNames) {
        $p = Join-Path $targetDir $s
        if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
    }
    # Only remove the directory if WE emptied it — never delete a dir holding
    # someone else's scripts.
    if ((Test-Path $targetDir) -and -not (Get-ChildItem -Force $targetDir)) {
        Remove-Item -Force $targetDir
    }
}
function Install-CopilotSkills {
    foreach ($s in $CopilotSkillNames) { Place (Join-Path $CopilotSkillsSrc $s) (Join-Path $CopilotSkills $s) }
}
function Remove-CopilotSkills {
    foreach ($s in $CopilotSkillNames) {
        $p = Join-Path $CopilotSkills $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}
function Install-CodexSkills {
    foreach ($s in $CodexSkillNames) { Place (Join-Path $CodexSkillsSrc $s) (Join-Path $CodexSkills $s) }
}
function Remove-CodexSkills {
    foreach ($s in $CodexSkillNames) {
        $p = Join-Path $CodexSkills $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}
function Test-ClaudeSkillsIn($dir) { Test-Path (Join-Path $dir 'orfi-kit-guardrails/SKILL.md') }

# --- NEW: settings.json hook wiring ------------------------------------------

function Get-ManualHookText {
@'
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-sync.sh\"", "timeout": 10 }
      ]
    }
'@
}

function Wire-Hook {
    Place $HookSrc $HookDest

    $reply = Read-Host "  Wire the hook into $ClaudeSettings automatically? [Y/n]"
    if ($reply -match '^[Nn]') {
        Say "  Skipped. Add this to .hooks.PreToolUse manually:"; Say (Get-ManualHookText); return
    }

    $dir = Split-Path -Parent $ClaudeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $ClaudeSettings)) { '{}' | Set-Content -Path $ClaudeSettings }

    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings is not valid JSON — not touching it. Add manually:"; Say (Get-ManualHookText); return }

    Backup-SettingsOnce
    Say "  backed up $ClaudeSettings -> $ClaudeSettings.bak"

    if (-not $json.hooks) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $json.hooks.PreToolUse) { $json.hooks | Add-Member -NotePropertyName PreToolUse -NotePropertyValue @() -Force }

    $already = @($json.hooks.PreToolUse | Where-Object {
        $_.matcher -eq 'Bash' -and ($_.hooks | Where-Object { $_.command -eq $HookCmd })
    }).Count -gt 0

    if ($already) {
        Say "  hook already wired — leaving settings.json unchanged (idempotent)"
    } else {
        $entry = [pscustomobject]@{
            matcher = 'Bash'
            hooks   = @([pscustomobject]@{ type = 'command'; command = $HookCmd; timeout = 10 })
        }
        $json.hooks.PreToolUse = @($json.hooks.PreToolUse) + $entry
        ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
        Say "  wired PreToolUse/Bash hook into settings.json"
    }
}

function Unwire-Hook {
    if (Test-Path $HookDest) { Remove-Item -Force $HookDest; Say "  removed $HookDest" }
    if (-not (Test-Path $ClaudeSettings)) { return }
    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks -or -not $json.hooks.PreToolUse) { return }

    Backup-SettingsOnce
    $kept = @($json.hooks.PreToolUse | Where-Object {
        -not ($_.matcher -eq 'Bash' -and ($_.hooks | Where-Object { $_.command -eq $HookCmd }))
    })
    $json.hooks.PreToolUse = $kept
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit PreToolUse entry from settings.json"
}

function Get-ManualBrevityText {
@'
    {
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh\"", "timeout": 10 }
      ]
    }
'@
}

function Wire-BrevityHook {
    Place $BrevitySrc $BrevityDest

    $dir = Split-Path -Parent $ClaudeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $ClaudeSettings)) { '{}' | Set-Content -Path $ClaudeSettings }

    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings is not valid JSON — not touching it. Add manually to .hooks.Stop:"; Say (Get-ManualBrevityText); return }

    Backup-SettingsOnce

    if (-not $json.hooks) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $json.hooks.Stop) { $json.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @() -Force }

    $already = @($json.hooks.Stop | Where-Object {
        $_.hooks | Where-Object { $_.command -eq $BrevityCmd }
    }).Count -gt 0

    if ($already) {
        Say "  brevity hook already wired — leaving settings.json unchanged (idempotent)"
    } else {
        $entry = [pscustomobject]@{
            hooks = @([pscustomobject]@{ type = 'command'; command = $BrevityCmd; timeout = 10 })
        }
        $json.hooks.Stop = @($json.hooks.Stop) + $entry
        ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
        Say "  wired Stop brevity hook into settings.json"
    }
}

function Unwire-BrevityHook {
    if (Test-Path $BrevityDest) { Remove-Item -Force $BrevityDest; Say "  removed $BrevityDest" }
    if (-not (Test-Path $ClaudeSettings)) { return }
    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks -or -not $json.hooks.Stop) { return }

    Backup-SettingsOnce
    $kept = @($json.hooks.Stop | Where-Object {
        -not ($_.hooks | Where-Object { $_.command -eq $BrevityCmd })
    })
    $json.hooks.Stop = $kept
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit Stop entry from settings.json"
}

# --- Skill-contract Stop hook: block reports whose mandated steps never ran ----
# Same shape as the brevity hook above. Larger timeout: this one greps a whole
# session transcript rather than measuring a single reply.

function Get-ManualContractText {
@'
    {
      "hooks": [
        { "type": "command", "command": "bash \"$HOME/.claude/hooks/orfi-kit-verify-skill-contract.sh\"", "timeout": 30 }
      ]
    }
'@
}

function Wire-ContractHook {
    Place $ContractSrc $ContractDest

    $dir = Split-Path -Parent $ClaudeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $ClaudeSettings)) { '{}' | Set-Content -Path $ClaudeSettings }

    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings is not valid JSON — not touching it. Add manually to .hooks.Stop:"; Say (Get-ManualContractText); return }

    Backup-SettingsOnce

    if (-not $json.hooks) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
    if (-not $json.hooks.Stop) { $json.hooks | Add-Member -NotePropertyName Stop -NotePropertyValue @() -Force }

    $already = @($json.hooks.Stop | Where-Object {
        $_.hooks | Where-Object { $_.command -eq $ContractCmd }
    }).Count -gt 0

    if ($already) {
        Say "  skill-contract hook already wired — leaving settings.json unchanged (idempotent)"
    } else {
        $entry = [pscustomobject]@{
            hooks = @([pscustomobject]@{ type = 'command'; command = $ContractCmd; timeout = 30 })
        }
        $json.hooks.Stop = @($json.hooks.Stop) + $entry
        ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
        Say "  wired Stop skill-contract hook into settings.json"
    }
}

function Unwire-ContractHook {
    if (Test-Path $ContractDest) { Remove-Item -Force $ContractDest; Say "  removed $ContractDest" }
    if (-not (Test-Path $ClaudeSettings)) { return }
    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks -or -not $json.hooks.Stop) { return }

    Backup-SettingsOnce
    $kept = @($json.hooks.Stop | Where-Object {
        -not ($_.hooks | Where-Object { $_.command -eq $ContractCmd })
    })
    $json.hooks.Stop = $kept
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit Stop contract entry from settings.json"
}

# --- Convention hooks: load before a write, verify after ----------------------
# Idempotent: an entry is added only when no existing entry already runs that
# exact command. The settings backup is taken ONCE per run (Backup-SettingsOnce)
# rather than per hook — otherwise wiring seven hooks would overwrite the .bak seven
# times. A pristine pre-orfi-kit copy is kept separately and written only once,
# because on a re-install settings.json already contains our entries.
$script:SettingsBackedUp = $false
function Backup-SettingsOnce {
    if ($script:SettingsBackedUp) { return }
    if (-not (Test-Path $ClaudeSettings)) { return }
    $pristine = "$ClaudeSettings.orfi-orig"
    if (-not (Test-Path $pristine)) {
        Copy-Item $ClaudeSettings $pristine -Force
        Say "  saved pristine pre-orfi-kit copy -> $pristine"
    }
    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
    Say "  backed up $ClaudeSettings -> $ClaudeSettings.bak"
    $script:SettingsBackedUp = $true
}

function Wire-ConventionHooks {
    foreach ($name in $ConvHookNames) {
        Place (Join-Path $RepoDir "claude/hooks/$name") (Join-Path $ClaudeHooks $name)
    }

    $dir = Split-Path -Parent $ClaudeSettings
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path $ClaudeSettings)) { '{}' | Set-Content -Path $ClaudeSettings }

    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings is not valid JSON — not touching it. Wire the convention hooks manually."; return }

    Backup-SettingsOnce

    if (-not $json.hooks) { $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }

    # The verifiers shell out to dotnet format / clang-tidy, which are slower than
    # a parse — give them a longer timeout than the loaders.
    foreach ($ev in @('PreToolUse','PostToolUse')) {
        if ($ev -eq 'PreToolUse') { $names = $ConvPreHooks; $timeout = 10 }
        else                      { $names = $ConvPostHooks; $timeout = 120 }

        if (-not $json.hooks.$ev) { $json.hooks | Add-Member -NotePropertyName $ev -NotePropertyValue @() -Force }

        foreach ($name in $names) {
            $cmd = 'bash "$HOME/.claude/hooks/' + $name + '"'
            $already = @($json.hooks.$ev | Where-Object {
                $_.hooks | Where-Object { $_.command -eq $cmd }
            }).Count -gt 0
            if (-not $already) {
                $entry = [pscustomobject]@{
                    matcher = $ConvMatcher
                    hooks   = @([pscustomobject]@{ type = 'command'; command = $cmd; timeout = $timeout })
                }
                $json.hooks.$ev = @($json.hooks.$ev) + $entry
            }
        }
    }
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  wired 2 PreToolUse loaders + 2 PostToolUse verifiers into settings.json (idempotent)"
}

function Unwire-ConventionHooks {
    foreach ($name in $ConvHookNames) {
        $p = Join-Path $ClaudeHooks $name
        if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
    }
    if (-not (Test-Path $ClaudeSettings)) { return }
    try { $json = Get-Content -Raw $ClaudeSettings | ConvertFrom-Json }
    catch { Say "  $ClaudeSettings not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks) { return }

    Backup-SettingsOnce
    foreach ($ev in @('PreToolUse','PostToolUse')) {
        if (-not $json.hooks.$ev) { continue }
        foreach ($name in $ConvHookNames) {
            $cmd = 'bash "$HOME/.claude/hooks/' + $name + '"'
            $json.hooks.$ev = @($json.hooks.$ev | Where-Object {
                -not ($_.hooks | Where-Object { $_.command -eq $cmd })
            })
        }
    }
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit convention hook entries from settings.json"
}

# --- Codex: skills to ~/.agents/skills, native hooks + global rules -------------
# ~/.codex/hooks.json and ~/.codex/AGENTS.md are THE user's own Codex files, so we
# MERGE (never overwrite): handlers are added when their command is not already
# registered, and the orfi-kit block is appended to AGENTS.md under a marker with a
# .bak backup. Invalid JSON is left untouched, with manual instructions instead.

function Install-CodexHooks {
    $dir = Split-Path -Parent $CodexHooksJson
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $CodexHooksJson) {
        try {
            $existing = Get-Content -Raw $CodexHooksJson | ConvertFrom-Json
            $ours     = Get-Content -Raw $CodexHooksJsonSrc | ConvertFrom-Json
        } catch {
            Say "  $CodexHooksJson is not valid JSON — not touching it."
            Say "  Add the handlers manually from codex/hooks.json in the orfi-kit repo."
            return
        }
        if (-not $existing.hooks) { $existing | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force }
        foreach ($ev in @('PreToolUse','PostToolUse')) {
            if (-not $existing.hooks.$ev) { $existing.hooks | Add-Member -NotePropertyName $ev -NotePropertyValue @() -Force }
            foreach ($h in @($ours.hooks.$ev)) {
                # Merge per-command, never per-handler: a source handler is reduced
                # to the commands the user's file does not already register, then
                # appended with its matcher. All present -> no-op (re-install is
                # idempotent); some present -> only the missing ones are added.
                $known = @($existing.hooks.$ev | ForEach-Object { $_.hooks | ForEach-Object { $_.command } })
                $missing = @($h.hooks | Where-Object { $known -notcontains $_.command })
                if ($missing.Count -gt 0) {
                    $entry = [pscustomobject]@{ matcher = $h.matcher; hooks = $missing }
                    $existing.hooks.$ev = @($existing.hooks.$ev) + $entry
                }
            }
        }
        if (-not $existing.PSObject.Properties.Name.Contains('description')) {
            $existing | Add-Member -NotePropertyName description -NotePropertyValue $ours.description -Force
        }
        ($existing | ConvertTo-Json -Depth 100) | Set-Content -Path $CodexHooksJson
        Say "  merged orfi-kit handlers into $CodexHooksJson"
    } else {
        Place $CodexHooksJsonSrc $CodexHooksJson
    }
}

function Remove-CodexHooks {
    if (-not (Test-Path $CodexHooksJson)) { return }
    try { $json = Get-Content -Raw $CodexHooksJson | ConvertFrom-Json }
    catch { Say "  $CodexHooksJson not valid JSON — leaving it untouched."; return }
    if (-not $json.hooks) { return }
    $kit = @('orfi-kit-enforce-sync.sh','orfi-kit-verify-csharp-format.sh','orfi-kit-verify-cpp-format.sh')
    foreach ($ev in @('PreToolUse','PostToolUse')) {
        if (-not $json.hooks.$ev) { continue }
        $json.hooks.$ev = @($json.hooks.$ev | Where-Object {
            $match = $false
            foreach ($h in @($_.hooks)) {
                foreach ($k in $kit) { if ($h.command -like "*$k*") { $match = $true } }
            }
            -not $match
        })
    }
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $CodexHooksJson
    Say "  removed orfi-kit handlers from $CodexHooksJson"
}

function Install-CodexAgents {
    $dir = Split-Path -Parent $CodexAgents
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $CodexAgents) {
        if (Select-String -Path $CodexAgents -Pattern '^# orfi-kit' -Quiet) {
            Say "  $CodexAgents already holds an orfi-kit block — leaving as-is (idempotent)"
            return
        }
        Copy-Item $CodexAgents "$CodexAgents.bak" -Force
        Say "  backed up $CodexAgents -> $CodexAgents.bak"
        Add-Content -Path $CodexAgents -Value ("`n`n" + (Get-Content -Raw $CodexAgentsSrc))
        Say "  appended orfi-kit block to $CodexAgents"
    } else {
        Place $CodexAgentsSrc $CodexAgents
    }
}

function Remove-CodexAgents {
    if (Test-Path "$CodexAgents.bak") {
        Move-Item -Force "$CodexAgents.bak" $CodexAgents
        Say "  restored $CodexAgents from its pre-orfi-kit backup"
    } elseif ((Test-Path $CodexAgents) -and (Select-String -Path $CodexAgents -Pattern '^# orfi-kit' -Quiet)) {
        Remove-Item -Force $CodexAgents
        Say "  removed $CodexAgents (no pre-existing content to preserve)"
    }
}

# --- NEW: Copilot extension (verified path ~/.copilot/extensions) ------------

function Install-CopilotExtension { Place $ExtSrc (Join-Path $CopilotExts 'orfi-kit-guardrails') }
function Remove-CopilotExtension {
    $p = Join-Path $CopilotExts 'orfi-kit-guardrails'
    if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
}

# --- Shared hooks for the OpenCode plugin and the Copilot hooks registration ---
# ~/.claude/hooks is the ONE home for the seven scripts regardless of runtime.
# Claude Code's Wire-* functions above place them; these helpers guarantee they
# exist for the OpenCode plugin and the Copilot hooks JSON when Claude Code is not
# part of the install.

function Install-SharedHooks {
    foreach ($name in $AllHookNames) {
        Place (Join-Path $RepoDir "claude/hooks/$name") (Join-Path $ClaudeHooks $name)
    }
}

function Remove-SharedHooks {
    foreach ($name in $AllHookNames) {
        $p = Join-Path $ClaudeHooks $name
        if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
    }
}

function Install-CopilotHooks { Place (Join-Path $CopilotHooksSrc 'orfi-kit.json') (Join-Path $CopilotHooks 'orfi-kit.json') }

function Remove-CopilotHooks {
    $p = Join-Path $CopilotHooks 'orfi-kit.json'
    if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
}

function Install-OpencodePlugin { Place (Join-Path $OpencodePluginsSrc 'orfi-kit-hooks.ts') (Join-Path $OpencodePlugins 'orfi-kit-hooks.ts') }

function Remove-OpencodePlugin {
    $p = Join-Path $OpencodePlugins 'orfi-kit-hooks.ts'
    if (Test-Path $p) { Remove-Item -Force $p; Say "  removed $p" }
}

# --- arg parsing -------------------------------------------------------------

if ($Help) { Show-Usage }
if (-not (Test-Path $SkillsSrc)) { Die "skills not found at $SkillsSrc - run this from the orfi-kit repo" }

# --- runtime selection -------------------------------------------------------

$WantCC = $false; $WantOC = $false; $WantCP = $false; $WantCX = $false

Say 'orfi-kit installer'
Say 'Install for which runtime(s)?'
Say '  1) Claude Code'
Say '  2) OpenCode'
Say '  3) GitHub Copilot CLI'
Say '  4) OpenAI Codex CLI'
Say "Select one or more (e.g. '1', '3', or '1 2 3' / '1,2' for several)."
$choice = Read-Host 'Choice'

foreach ($n in ($choice -split '[,\s]+' | Where-Object { $_ -ne '' })) {
    switch ($n) {
        '1' { $WantCC = $true }
        '2' { $WantOC = $true }
        '3' { $WantCP = $true }
        '4' { $WantCX = $true }
        default { Die "invalid choice: '$n' (pick 1, 2, 3 and/or 4)" }
    }
}
if (-not ($WantCC -or $WantOC -or $WantCP -or $WantCX)) { Die 'no runtime selected' }

# --- uninstall ---------------------------------------------------------------

if ($Uninstall) {
    Say ''
    Say 'Uninstalling orfi-kit...'
    if ($WantCC) { Remove-ClaudeSkillsFrom $ClaudeSkills; Remove-CommandsFrom $ClaudeCmds; Remove-ScriptsFrom $ClaudeScripts; Unwire-Hook; Unwire-BrevityHook; Unwire-ConventionHooks; Unwire-ContractHook }
    if ($WantOC) { Remove-ClaudeSkillsFrom $OpencodeSkills; Remove-CommandsFrom $OpencodeCmds; Remove-ScriptsFrom $OpencodeScripts; Remove-OpencodePlugin }
    if ($WantCP) { Remove-CopilotSkills; Remove-CopilotExtension; Remove-CopilotHooks; Remove-ScriptsFrom $CopilotScripts }
    if ($WantCX) { Remove-CodexSkills; Remove-CodexHooks; Remove-CodexAgents }
    # Shared scripts in ~/.claude/hooks were placed here only when Claude Code was
    # not part of the install; Claude's own uninstall already removes them above.
    if ((-not $WantCC) -and ($WantOC -or $WantCP -or $WantCX)) { Remove-SharedHooks }
    Say 'Done.'
    exit 0
}

# --- install: skills + commands ----------------------------------------------

Say ''

if ($WantCC -and $WantOC) {
    Say 'Claude Code + OpenCode - skills go to ~/.claude/skills (OpenCode reads it natively).'
    Install-ClaudeSkillsTo $ClaudeSkills
    if (Test-ClaudeSkillsIn $OpencodeSkills) {
        Say 'Removing duplicate skills under OpenCode to avoid drift:'
        Remove-ClaudeSkillsFrom $OpencodeSkills
    }
    Install-CommandsTo $ClaudeCmds
    Install-CommandsTo $OpencodeCmds
}
elseif ($WantCC) {
    Install-ClaudeSkillsTo $ClaudeSkills
    Install-CommandsTo $ClaudeCmds
}
elseif ($WantOC) {
    if (Test-ClaudeSkillsIn $ClaudeSkills) {
        Say 'Found existing skills in ~/.claude/skills - OpenCode reads that path natively,'
        Say 'so skills are left there (not duplicated under OpenCode).'
    } else {
        Install-ClaudeSkillsTo $OpencodeSkills
    }
    Install-CommandsTo $OpencodeCmds
}

# Doc-presence checkers + hook wiring. Installed per selected runtime as a
# FALLBACK copy — a project's own scripts/ still wins (see $ScriptNames above).
Say ''
Say 'Installing doc-checker scripts (xml-docs + doxygen-docs, and setup-hooks):'
if ($WantCC) { Install-ScriptsTo $ClaudeScripts }
if ($WantOC) { Install-ScriptsTo $OpencodeScripts }
if ($WantCP) { Install-ScriptsTo $CopilotScripts }
Say '  (project tooling: copy them into a repo''s scripts/ so its CI can run them,'
Say '   and run setup-hooks there once to wire .githooks/pre-commit)'

if ($WantCC) {
    Say ''
    Say 'Installing sync-enforcement hook (Claude Code):'
    Wire-Hook
    Say ''
    Say 'Installing brevity-enforcement Stop hook (Claude Code):'
    Wire-BrevityHook
    Say ""
    Say "Installing convention hooks (Claude Code) — load before a write, verify after:"
    Wire-ConventionHooks
    Say ""
    Say "Installing skill-contract Stop hook (Claude Code) — blocks a report whose"
    Say "mandated steps have no record in the transcript:"
    Wire-ContractHook
}

# The seven scripts must be under ~/.claude/hooks for the OpenCode plugin and the
# Copilot + Codex hooks registrations. Claude Code placed them above; any other
# runtime that was selected ensures they exist.
if ((-not $WantCC) -and ($WantOC -or $WantCP -or $WantCX)) {
    Say ''
    Say 'Installing shared enforcement hooks to ~/.claude/hooks (used by the Copilot'
    Say 'hooks registration, the Codex hooks.json, and the OpenCode plugin):'
    Install-SharedHooks
}

if ($WantOC) {
    Say ''
    Say 'Installing OpenCode plugin (orfi-kit-hooks.ts):'
    Install-OpencodePlugin
}

# --- GitHub Copilot CLI + extension + hooks -----------------------------------

if ($WantCP) {
    Say ''
    Say 'GitHub Copilot CLI - skills go to ~/.copilot/skills (the skill is its own slash command).'
    Install-CopilotSkills
    Say 'Installing Copilot guardrails extension to ~/.copilot/extensions:'
    Install-CopilotExtension
    Say 'Installing Copilot hooks registration to ~/.copilot/hooks:'
    Install-CopilotHooks
}

# --- OpenAI Codex CLI: skills + native hooks + global rules --------------------

if ($WantCX) {
    Say ''
    Say 'OpenAI Codex CLI - skills go to ~/.agents/skills (Codex native user scope).'
    Say 'Invoke them by bare name (orfi-kit-commit, orfi-kit-code-review, ...) - Codex has'
    Say 'no slash-command skill references. C#/C++ reviewers run with their stored approval:'
    Install-CodexSkills
    Say ''
    Say 'Installing native hooks registration to ~/.codex/hooks.json (5 of 7 hooks; the Stop'
    Say 'contracts - brevity, skill-contract - are deliberately NOT wired: Codex has no stable'
    Say 'Stop hook contract, so they run as an explicit checklist in AGENTS.md instead):'
    Install-CodexHooks
    Say ''
    Say 'Installing Codex global rules to ~/.codex/AGENTS.md (guardrails + conventions):'
    Install-CodexAgents
}

Say ''
Say 'Done. For Codex, invoke skills by bare name (orfi-kit-commit / orfi-kit-code-review).'
