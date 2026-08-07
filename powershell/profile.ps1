# Shared interactive PowerShell profile for this Windows machine.
# Installed to both Windows PowerShell and PowerShell 7 CurrentUserAllHosts profiles.

# Bash-style command-line editing in PowerShell.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs

    Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord Ctrl+k -Function KillLine
    Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardKillLine
    Set-PSReadLineKeyHandler -Chord Ctrl+w -Function BackwardKillWord
}

function orz {
    $copilotArgs = @()
    if ($env:ZELLIJ) {
        $copilotArgs += "--no-color"
        $copilotArgs += "--mouse"
    }
    $copilotArgs += $args

    if (Get-Command agency -ErrorAction SilentlyContinue) {
        agency copilot @copilotArgs
    } else {
        copilot @copilotArgs
    }
}

function ll {
    Get-ChildItem -Force @args
}

function la {
    Get-ChildItem -Force @args
}

function l {
    Get-ChildItem @args
}

function gs {
    git status --short --branch @args
}

function ga {
    git add @args
}

function gco {
    git checkout @args
}

function gb {
    git branch @args
}

function gd {
    git diff @args
}

function gl {
    git log --oneline --decorate --graph -20 @args
}

function grep {
    if (Get-Command rg -ErrorAction SilentlyContinue) {
        rg @args
    } else {
        Select-String @args
    }
}

function which {
    Get-Command @args
}

function touch {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Path
    )

    foreach ($item in $Path) {
        if (Test-Path -LiteralPath $item) {
            (Get-Item -LiteralPath $item).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $item -Force | Out-Null
        }
    }
}

function croot {
    Set-Location "$HOME\claude-code-config"
}

function agentic {
    Set-Location "$HOME\claude-code-config"
    zellij
}
. "C:\Users\t-michaelxu\.claude-remote.ps1"
