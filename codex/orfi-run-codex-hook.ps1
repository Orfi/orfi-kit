param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('enforce-sync', 'verify-csharp-format', 'verify-cpp-format')]
    [string]$HookName
)

# Native stderr must not terminate PowerShell before the child exit code is relayed.
$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8

$hookPath = Join-Path $PSScriptRoot "orfi-kit-$HookName.sh"
if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
    [Console]::Error.WriteLine("orfi-kit: hook script not found: $hookPath")
    exit 1
}

# Never resolve the Windows/WSL bash.exe shim for these Git Bash scripts.
$candidates = @()
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitDirectory = Split-Path -Parent $gitCommand.Source
    $candidates += [IO.Path]::GetFullPath((Join-Path $gitDirectory '../bin/bash.exe'))
}
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
    if ($base) { $candidates += Join-Path $base 'Git/bin/bash.exe' }
}
$bashPath = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $bashPath) {
    [Console]::Error.WriteLine('orfi-kit: Git Bash not found; install Git for Windows before running Codex hooks.')
    exit 1
}

$env:ORFI_HOOK_PLATFORM = 'codex'
$payload = [Console]::In.ReadToEnd()
$payload | & $bashPath $hookPath
exit $LASTEXITCODE
