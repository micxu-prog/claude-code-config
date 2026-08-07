#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Symlink,
    [switch]$Copy,
    [switch]$Force,
    [switch]$InstallZellij
)

$ErrorActionPreference = "Stop"

if ($Symlink -and $Copy) {
    throw "Choose either -Symlink or -Copy, not both."
}
if (-not $Symlink -and -not $Copy) {
    $Symlink = $true
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
$CopilotDir = Join-Path $env:USERPROFILE ".copilot"
$ZellijDir = Join-Path $env:USERPROFILE ".config\zellij"
$UserBinDir = Join-Path $env:USERPROFILE "bin"
$DocumentsDir = [Environment]::GetFolderPath("MyDocuments")
$WindowsPowerShellProfile = Join-Path $DocumentsDir "WindowsPowerShell\profile.ps1"
$PowerShellProfile = Join-Path $DocumentsDir "PowerShell\profile.ps1"
$BackupStamp = Get-Date -Format "yyyyMMddHHmmss"

function Info($Message) { Write-Host "[info] $Message" -ForegroundColor Cyan }
function Ok($Message) { Write-Host "[ok]   $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "[warn] $Message" -ForegroundColor Yellow }

function Ensure-Directory {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path -PathType Container) {
        return
    }

    if ($DryRun) {
        Info "would create directory: $Path"
    } else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Info "created directory: $Path"
    }
}

function Get-LinkTarget {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return $null
    }

    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $item.PSObject.Properties["Target"]) {
        return $item.Target
    }

    return $null
}

function Same-ResolvedPath {
    param(
        [string]$Left,
        [string]$Right
    )

    try {
        $resolvedLeft = [IO.Path]::GetFullPath($Left).TrimEnd("\")
        $resolvedRight = [IO.Path]::GetFullPath($Right).TrimEnd("\")
        return [string]::Equals($resolvedLeft, $resolvedRight, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Install-File {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Source file not found: $Source"
    }

    Ensure-Directory (Split-Path -Parent $Destination)

    $exists = Test-Path -LiteralPath $Destination
    if ($exists) {
        $target = Get-LinkTarget $Destination
        if ($Symlink -and $target -and (Same-ResolvedPath $target $Source)) {
            Ok "already linked: $Destination"
            return
        }

        if (-not $Force) {
            $backup = "$Destination.bak-$BackupStamp"
            if ($DryRun) {
                Info "would back up: $Destination -> $backup"
            } else {
                Copy-Item -LiteralPath $Destination -Destination $backup -Force
                Info "backed up: $Destination -> $backup"
            }
        }

        if ($DryRun) {
            Info "would remove existing: $Destination"
        } else {
            Remove-Item -LiteralPath $Destination -Force
        }
    }

    if ($Symlink) {
        if ($DryRun) {
            Info "would link: $Destination -> $Source"
        } else {
            try {
                New-Item -ItemType SymbolicLink -Path $Destination -Target $Source -Force | Out-Null
                Ok "linked: $Destination -> $Source"
            } catch {
                Warn "symlink failed for $Destination; trying a hard link"
                try {
                    New-Item -ItemType HardLink -Path $Destination -Target $Source -Force | Out-Null
                    Ok "hard-linked: $Destination -> $Source"
                } catch {
                    throw "Could not link '$Destination'. Enable Developer Mode, run as administrator, or rerun with -Copy. $($_.Exception.Message)"
                }
            }
        }
    } else {
        if ($DryRun) {
            Info "would copy: $Source -> $Destination"
        } else {
            Copy-Item -LiteralPath $Source -Destination $Destination -Force
            Ok "copied: $Source -> $Destination"
        }
    }
}

function Add-FileMapping {
    param(
        [System.Collections.Generic.List[object]]$Mappings,
        [string]$Source,
        [string]$Destination
    )

    $Mappings.Add([pscustomobject]@{ Source = $Source; Destination = $Destination }) | Out-Null
}

function Add-TreeMappings {
    param(
        [System.Collections.Generic.List[object]]$Mappings,
        [string]$SourceDir,
        [string]$DestinationDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        return
    }

    Get-ChildItem -LiteralPath $SourceDir -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($SourceDir.Length).TrimStart("\")
        Add-FileMapping $Mappings $_.FullName (Join-Path $DestinationDir $relative)
    }
}

function Validate-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
    Ok "json valid: $Path"
}

function Validate-PowerShellFile {
    param([string]$Path)

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors -and $errors.Count -gt 0) {
        throw "PowerShell parse failed for $Path`: $($errors[0].Message)"
    }
    Ok "powershell valid: $Path"
}

Write-Host "=== agentic coding config installer for Windows ==="
Info "repo: $RepoRoot"
if ($Symlink) { Info "mode: symlink" } else { Info "mode: copy" }
if ($DryRun) { Warn "dry-run: no changes will be made" }
Write-Host ""

if ($InstallZellij) {
    & (Join-Path $PSScriptRoot "install-zellij-windows.ps1")
}

$mappings = New-Object System.Collections.Generic.List[object]
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\settings.json") (Join-Path $CopilotDir "settings.json")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\copilot-instructions.md") (Join-Path $CopilotDir "copilot-instructions.md")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\mcp-config.json") (Join-Path $CopilotDir "mcp-config.json")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\lsp-config.json") (Join-Path $CopilotDir "lsp-config.json")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\ado-mcp.cmd") (Join-Path $CopilotDir "ado-mcp.cmd")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\statusline-command.cmd") (Join-Path $CopilotDir "statusline-command.cmd")
Add-FileMapping $mappings (Join-Path $RepoRoot "copilot\statusline-command.ps1") (Join-Path $CopilotDir "statusline-command.ps1")
Add-TreeMappings $mappings (Join-Path $RepoRoot "copilot\hooks") (Join-Path $CopilotDir "hooks")
Add-TreeMappings $mappings (Join-Path $RepoRoot "copilot\agents") (Join-Path $CopilotDir "agents")
Add-TreeMappings $mappings (Join-Path $RepoRoot "copilot\skills") (Join-Path $CopilotDir "skills")
Add-FileMapping $mappings (Join-Path $RepoRoot "zellij\config.kdl") (Join-Path $ZellijDir "config.kdl")
Add-TreeMappings $mappings (Join-Path $RepoRoot "zellij\layouts") (Join-Path $ZellijDir "layouts")
Add-FileMapping $mappings (Join-Path $RepoRoot "powershell\profile.ps1") $WindowsPowerShellProfile
Add-FileMapping $mappings (Join-Path $RepoRoot "powershell\profile.ps1") $PowerShellProfile
Add-TreeMappings $mappings (Join-Path $RepoRoot "bin") $UserBinDir

foreach ($mapping in $mappings) {
    Install-File $mapping.Source $mapping.Destination
}

if ($DryRun) {
    Info "would set user ZELLIJ_CONFIG_DIR=$ZellijDir"
} else {
    [Environment]::SetEnvironmentVariable("ZELLIJ_CONFIG_DIR", $ZellijDir, "User")
    Ok "set user ZELLIJ_CONFIG_DIR=$ZellijDir"
}

Write-Host ""
Info "validating repo-managed config files"
Validate-JsonFile (Join-Path $RepoRoot "copilot\settings.json")
Validate-JsonFile (Join-Path $RepoRoot "copilot\mcp-config.json")
Validate-JsonFile (Join-Path $RepoRoot "copilot\lsp-config.json")
Get-ChildItem -LiteralPath (Join-Path $RepoRoot "copilot\hooks") -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Validate-JsonFile $_.FullName
}
Validate-PowerShellFile (Join-Path $RepoRoot "copilot\statusline-command.ps1")
Validate-PowerShellFile (Join-Path $RepoRoot "copilot\hooks\format-python.ps1")
Validate-PowerShellFile (Join-Path $RepoRoot "powershell\profile.ps1")

Write-Host ""
Info "tool availability"
foreach ($tool in @("copilot", "zellij", "git", "node", "npx", "ruff", "pyright-langserver", "typescript-language-server")) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if ($cmd) {
        Ok "${tool}: $($cmd.Source)"
    } else {
        Warn "$tool not found"
    }
}

Write-Host ""
Ok "installation complete"
Info "restart Copilot CLI and your terminal so settings, hooks, skills, agents, and ZELLIJ_CONFIG_DIR reload"
