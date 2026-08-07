#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Info($Message) { Write-Host "[info] $Message" -ForegroundColor Cyan }
function Ok($Message) { Write-Host "[ok]   $Message" -ForegroundColor Green }
function Warn($Message) { Write-Host "[warn] $Message" -ForegroundColor Yellow }

function Download-File {
    param(
        [string]$Uri,
        [string]$OutFile
    )

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & curl.exe -L --fail --silent --show-error -o "$OutFile" "$Uri"
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed to download $Uri"
        }
        return
    }

    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}

$installDir = Join-Path $env:LOCALAPPDATA "Programs\zellij"
$installedExe = Join-Path $installDir "zellij.exe"
$configDir = Join-Path $env:USERPROFILE ".config\zellij"

function Ensure-UserPath {
    param([string]$Directory)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathParts = @()
    if ($userPath) {
        $pathParts = $userPath -split ";"
    }

    if ($pathParts -notcontains $Directory) {
        $newPath = if ($userPath) { "$userPath;$Directory" } else { $Directory }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Warn "added Zellij to the user PATH; restart the terminal for PATH changes to apply"
    }

    $processPathParts = $env:Path -split ";"
    if ($processPathParts -notcontains $Directory) {
        $env:Path = "$env:Path;$Directory"
    }
}

$existing = Get-Command zellij -ErrorAction SilentlyContinue
if (($existing -or (Test-Path -LiteralPath $installedExe -PathType Leaf)) -and -not $Force) {
    $zellijPath = if ($existing) { $existing.Source } else { $installedExe }
    Ensure-UserPath $installDir
    [Environment]::SetEnvironmentVariable("ZELLIJ_CONFIG_DIR", $configDir, "User")
    Ok "zellij already available: $zellijPath"
    & $zellijPath --version
    exit 0
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("zellij-install-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    Info "fetching latest Zellij release metadata"
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/zellij-org/zellij/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -eq "zellij-x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
    if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -eq "zellij-no-web-x86_64-pc-windows-msvc.zip" } | Select-Object -First 1
    }
    if (-not $asset) {
        throw "Could not find a Windows x86_64 Zellij zip asset in the latest release."
    }

    $zipPath = Join-Path $tempRoot $asset.name
    Info "downloading $($asset.name)"
    Download-File $asset.browser_download_url $zipPath

    $expectedHash = $null
    if ($asset.PSObject.Properties["digest"] -and "$($asset.digest)" -match "^sha256:(.+)$") {
        $expectedHash = $Matches[1].ToLowerInvariant()
    }

    if ($expectedHash) {
        Info "verifying SHA256"
        $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expectedHash -ne $actualHash) {
            throw "SHA256 mismatch for $($asset.name)."
        }
    } else {
        Warn "release asset digest not found; skipping SHA256 verification"
    }

    Info "extracting Zellij"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempRoot -Force
    $zellijExe = Get-ChildItem -LiteralPath $tempRoot -Filter "zellij.exe" -Recurse | Select-Object -First 1
    if (-not $zellijExe) {
        throw "Archive did not contain zellij.exe."
    }

    Copy-Item -LiteralPath $zellijExe.FullName -Destination (Join-Path $installDir "zellij.exe") -Force
    Ok "installed zellij.exe to $installDir"

    Ensure-UserPath $installDir
    [Environment]::SetEnvironmentVariable("ZELLIJ_CONFIG_DIR", $configDir, "User")
    Ok "set user ZELLIJ_CONFIG_DIR=$configDir"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
