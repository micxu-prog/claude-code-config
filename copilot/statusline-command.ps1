$inputJson = [Console]::In.ReadToEnd()
$esc = [char]27

$reset = "${esc}[0m"
$cVer = "${esc}[38;5;39m"
$cCtx = "${esc}[38;5;208m"
$cModel = "${esc}[38;5;141m"
$cDir = "${esc}[38;5;78m"
$cBranch = "${esc}[38;5;220m"
$cSshOn = "${esc}[38;5;46m"
$cSshOff = "${esc}[38;5;196m"
$cAutoYesOn = "${esc}[38;5;46m"
$cAutoYesOff = "${esc}[38;5;196m"
$sep = "${esc}[38;5;240m | ${esc}[0m"

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

function First-Value {
    param([object[]]$Values)

    foreach ($value in $Values) {
        if ($null -ne $value -and "$value" -ne "") {
            return $value
        }
    }

    return $null
}

function Short-Path {
    param(
        [string]$Path,
        [int]$MaxSegments = 2
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $trimmed = $Path.TrimEnd("\", "/")
    $parts = @($trimmed -split "[\\/]" | Where-Object { $_ -ne "" })
    if ($parts.Count -le $MaxSegments) {
        return $trimmed
    }

    $tail = @($parts | Select-Object -Last $MaxSegments)
    return "...\$($tail -join '\')"
}

function Get-ChatName {
    param([object]$Data)

    $name = First-Value @(
        (Get-Prop $Data @("session", "name")),
        (Get-Prop $Data @("session", "title")),
        (Get-Prop $Data @("conversation", "name")),
        (Get-Prop $Data @("conversation", "title")),
        (Get-Prop $Data @("chat", "name")),
        (Get-Prop $Data @("chat", "title")),
        (Get-Prop $Data @("task", "title")),
        (Get-Prop $Data @("sessionName")),
        (Get-Prop $Data @("session_name")),
        (Get-Prop $Data @("title")),
        (Get-Prop $Data @("name"))
    )

    if ($null -ne $name -and $name.PSObject.Properties["name"]) {
        $name = $name.name
    }
    if ($null -ne $name -and $name.PSObject.Properties["title"]) {
        $name = $name.title
    }

    if ([string]::IsNullOrWhiteSpace("$name")) {
        return "Copilot Chat"
    }

    return "$name"
}

try {
    if ([string]::IsNullOrWhiteSpace($inputJson)) {
        $data = $null
    } else {
        $data = $inputJson | ConvertFrom-Json
    }
} catch {
    Write-Output "${cVer}Copilot Chat${reset}${sep}${cCtx}status input unavailable${reset}"
    exit 0
}

$chatName = Get-ChatName $data
$modelValue = First-Value @(
    (Get-Prop $data @("model", "display_name")),
    (Get-Prop $data @("model", "displayName")),
    (Get-Prop $data @("modelName")),
    (Get-Prop $data @("model"))
)

if ($null -ne $modelValue -and $modelValue.PSObject.Properties["display_name"]) {
    $modelValue = $modelValue.display_name
}

$modelValue = "$modelValue" -replace "^GitHub Copilot\s+", "" -replace "^Copilot\s+", ""

$effort = First-Value @(
    (Get-Prop $data @("effortLevel")),
    (Get-Prop $data @("effort_level")),
    (Get-Prop $data @("model", "effortLevel")),
    (Get-Prop $data @("model", "effort_level"))
)

$contextPercent = First-Value @(
    (Get-Prop $data @("context_window", "used_percentage")),
    (Get-Prop $data @("contextWindow", "usedPercentage")),
    (Get-Prop $data @("context", "usedPercentage")),
    (Get-Prop $data @("context", "used_percentage"))
)

$cwd = First-Value @(
    (Get-Prop $data @("workspace", "current_dir")),
    (Get-Prop $data @("workspace", "currentDir")),
    (Get-Prop $data @("cwd")),
    (Get-Location).Path
)

$branch = $null
if ($cwd -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $insideGit = & git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0 -and "$insideGit" -eq "true") {
        $branch = & git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>$null
        if ([string]::IsNullOrWhiteSpace($branch)) {
            $branch = & git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>$null
        }
    }
}

$isSsh = -not [string]::IsNullOrWhiteSpace($env:SSH_CONNECTION) -or
    -not [string]::IsNullOrWhiteSpace($env:SSH_CLIENT) -or
    -not [string]::IsNullOrWhiteSpace($env:SSH_TTY)
$sshText = if ($isSsh) { "SSH: YES" } else { "SSH: NO" }
$sshColor = if ($isSsh) { $cSshOn } else { $cSshOff }

$modelText = $null
if ($modelValue) {
    if ($effort) {
        $modelText = "$modelValue/$effort"
    } else {
        $modelText = "$modelValue"
    }
}

$line = "${cVer}${chatName}${reset}${sep}"
if ($contextPercent) {
    $line += "${cCtx}Context: $contextPercent%${reset}${sep}"
}
if ($modelText) {
    $line += "${cModel}($modelText)${reset}${sep}"
}
$line += "${sshColor}${sshText}${reset}${sep}"
if ($cwd) {
    $line += "${cDir}DIR: $(Short-Path $cwd)${reset}"
}
if ($branch) {
    $line += "${sep}${cBranch}Branch: $branch${reset}"
}

$autoYesStateFile = Join-Path $HOME ".autoyes\state"
if (Test-Path -LiteralPath $autoYesStateFile) {
    $autoYesState = Get-Content -LiteralPath $autoYesStateFile -TotalCount 1 -ErrorAction SilentlyContinue
    $autoYesPid = Get-Content -LiteralPath $autoYesStateFile -Tail 1 -ErrorAction SilentlyContinue

    if ($autoYesPid -match "^\d+$" -and (Get-Process -Id ([int]$autoYesPid) -ErrorAction SilentlyContinue)) {
        if ($autoYesState -eq "ON") {
            $line += "${sep}${cAutoYesOn}AutoYes: ON${reset}"
        } else {
            $line += "${sep}${cAutoYesOff}AutoYes: OFF${reset}"
        }
    } else {
        Remove-Item -LiteralPath $autoYesStateFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Output $line
