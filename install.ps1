#!/usr/bin/env pwsh
#
# orfi-kit installer (PowerShell) — the cross-platform twin of install.sh.
# Runs on Windows PowerShell 5+, and pwsh on Windows / macOS / Linux.
#
# orfi-kit is skills/markdown plus one hook and one Copilot extension. This
# script is install-time plumbing only.
#
# Usage:
#   ./install.ps1                 interactive: asks which runtime(s) to install for
#   ./install.ps1 -Link           symlink instead of copy (dev: repo edits go live)
#   ./install.ps1 -Uninstall      remove an existing orfi-kit install
#   ./install.ps1 -Help           show this help
#
# Claude Code + OpenCode share one skill source (claude/skills) and the 10
# command files. Copilot uses its own source (copilot/skills) and its own home
# (~/.copilot/skills). settings.json file-mode is only meaningful on POSIX.

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
$CmdsSrc          = Join-Path $RepoDir 'claude/commands'
$HookSrc          = Join-Path $RepoDir 'claude/hooks/orfi-kit-enforce-sync.sh'
$BrevitySrc       = Join-Path $RepoDir 'claude/hooks/orfi-kit-enforce-brevity.sh'
$ExtSrc           = Join-Path $RepoDir 'copilot/extensions/orfi-kit-guardrails'

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

$HookDest = Join-Path $ClaudeHooks 'orfi-kit-enforce-sync.sh'
$HookCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-enforce-sync.sh"'

$BrevityDest = Join-Path $ClaudeHooks 'orfi-kit-enforce-brevity.sh'
$BrevityCmd  = 'bash "$HOME/.claude/hooks/orfi-kit-enforce-brevity.sh"'

$ClaudeSkillNames = @('orfi-kit-git-conventions','orfi-kit-guardrails','orfi-kit-scrum-poker','orfi-kit-xml-docs','orfi-kit-doxygen-docs','orfi-kit-csharp-code-review')

$CopilotSkillNames = @(
  'orfi-kit-cleanup-state','orfi-kit-code-review','orfi-kit-commit','orfi-kit-csharp-code-review',
  'orfi-kit-enforce-guardrails',
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
function Install-CopilotSkills {
    foreach ($s in $CopilotSkillNames) { Place (Join-Path $CopilotSkillsSrc $s) (Join-Path $CopilotSkills $s) }
}
function Remove-CopilotSkills {
    foreach ($s in $CopilotSkillNames) {
        $p = Join-Path $CopilotSkills $s
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

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
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

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
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

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force

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

    Copy-Item $ClaudeSettings "$ClaudeSettings.bak" -Force
    $kept = @($json.hooks.Stop | Where-Object {
        -not ($_.hooks | Where-Object { $_.command -eq $BrevityCmd })
    })
    $json.hooks.Stop = $kept
    ($json | ConvertTo-Json -Depth 100) | Set-Content -Path $ClaudeSettings
    Say "  removed orfi-kit Stop entry from settings.json"
}

# --- NEW: Copilot extension (verified path ~/.copilot/extensions) ------------

function Install-CopilotExtension { Place $ExtSrc (Join-Path $CopilotExts 'orfi-kit-guardrails') }
function Remove-CopilotExtension {
    $p = Join-Path $CopilotExts 'orfi-kit-guardrails'
    if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
}

# --- arg parsing -------------------------------------------------------------

if ($Help) { Show-Usage }
if (-not (Test-Path $SkillsSrc)) { Die "skills not found at $SkillsSrc - run this from the orfi-kit repo" }

# --- runtime selection -------------------------------------------------------

$WantCC = $false; $WantOC = $false; $WantCP = $false

Say 'orfi-kit installer'
Say 'Install for which runtime(s)?'
Say '  1) Claude Code'
Say '  2) OpenCode'
Say '  3) GitHub Copilot CLI'
Say "Select one or more (e.g. '1', '3', or '1 2 3' / '1,2' for several)."
$choice = Read-Host 'Choice'

foreach ($n in ($choice -split '[,\s]+' | Where-Object { $_ -ne '' })) {
    switch ($n) {
        '1' { $WantCC = $true }
        '2' { $WantOC = $true }
        '3' { $WantCP = $true }
        default { Die "invalid choice: '$n' (pick 1, 2 and/or 3)" }
    }
}
if (-not ($WantCC -or $WantOC -or $WantCP)) { Die 'no runtime selected' }

# --- uninstall ---------------------------------------------------------------

if ($Uninstall) {
    Say ''
    Say 'Uninstalling orfi-kit...'
    if ($WantCC) { Remove-ClaudeSkillsFrom $ClaudeSkills; Remove-CommandsFrom $ClaudeCmds; Unwire-Hook; Unwire-BrevityHook }
    if ($WantOC) { Remove-ClaudeSkillsFrom $OpencodeSkills; Remove-CommandsFrom $OpencodeCmds }
    if ($WantCP) { Remove-CopilotSkills; Remove-CopilotExtension }
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

if ($WantCC) {
    Say ''
    Say 'Installing sync-enforcement hook (Claude Code):'
    Wire-Hook
    Say ''
    Say 'Installing brevity-enforcement Stop hook (Claude Code):'
    Wire-BrevityHook
}

# --- Copilot CLI + extension -------------------------------------------------

if ($WantCP) {
    Say ''
    Say 'GitHub Copilot CLI - skills go to ~/.copilot/skills (the skill is its own slash command).'
    Install-CopilotSkills
    Say 'Installing Copilot guardrails extension to ~/.copilot/extensions:'
    Install-CopilotExtension
}

Say ''
Say 'Done. Invoke with /orfi-kit-commit or /orfi-kit-code-review'
