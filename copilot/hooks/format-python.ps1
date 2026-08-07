$inputJson = [Console]::In.ReadToEnd()

function Write-HookJson {
    param([hashtable]$Value)

    if ($null -eq $Value -or $Value.Count -eq 0) {
        Write-Output "{}"
        return
    }

    Write-Output ($Value | ConvertTo-Json -Compress -Depth 6)
}

function Get-Prop {
    param(
        [object]$Object,
        [string[]]$Path
    )

    $current = $Object
    foreach ($part in $Path) {
        if ($null -eq $current) {
            return $null
        }

        $property = $current.PSObject.Properties[$part]
        if ($null -eq $property) {
            return $null
        }

        $current = $property.Value
    }

    return $current
}

try {
    $payload = $inputJson | ConvertFrom-Json
} catch {
    Write-HookJson @{ additionalContext = "Python formatting hook could not parse the Copilot hook payload." }
    exit 0
}

$toolName = Get-Prop $payload @("toolName")
if (-not $toolName) {
    $toolName = Get-Prop $payload @("tool_name")
}

if ($toolName -and $toolName -notin @("edit", "create")) {
    Write-HookJson @{}
    exit 0
}

$filePath = Get-Prop $payload @("toolArgs", "file_path")
if (-not $filePath) { $filePath = Get-Prop $payload @("toolArgs", "path") }
if (-not $filePath) { $filePath = Get-Prop $payload @("tool_input", "file_path") }
if (-not $filePath) { $filePath = Get-Prop $payload @("tool_input", "path") }

if (-not $filePath -or [IO.Path]::GetExtension("$filePath") -ne ".py") {
    Write-HookJson @{}
    exit 0
}

if (-not [IO.Path]::IsPathRooted("$filePath")) {
    $cwd = Get-Prop $payload @("cwd")
    if ($cwd) {
        $filePath = Join-Path "$cwd" "$filePath"
    }
}

if (-not (Test-Path -LiteralPath "$filePath" -PathType Leaf)) {
    Write-HookJson @{}
    exit 0
}

if (-not (Get-Command ruff -ErrorAction SilentlyContinue)) {
    Write-HookJson @{}
    exit 0
}

$messages = New-Object System.Collections.Generic.List[string]
& ruff check --fix "$filePath" 2>&1 | ForEach-Object { $messages.Add("$($_)") }
$checkExit = $LASTEXITCODE
& ruff format "$filePath" 2>&1 | ForEach-Object { $messages.Add("$($_)") }
$formatExit = $LASTEXITCODE

if ($checkExit -ne 0 -or $formatExit -ne 0) {
    $detail = ($messages | Select-Object -First 20) -join "`n"
    Write-HookJson @{ additionalContext = "Python formatting hook failed for $filePath.`n$detail" }
    exit 0
}

Write-HookJson @{}
