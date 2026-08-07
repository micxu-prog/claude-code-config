<#
.SYNOPSIS
  Commute preflight: switch this laptop from corp WiFi to a cached phone hotspot,
  stop corp WiFi from roaming back, and VERIFY the Anthropic API is reachable over
  cellular - all before the agent commits to a lid-closed commute.

.DESCRIPTION
  Bundled with the 'commute' skill. Reads hotspots.json (same folder) for cached
  SSID/password so reconnecting is one command. Designed to be SAFE: it verifies
  end-to-end reachability (DNS + raw internet + api.anthropic.com) and returns a
  clear PASS/FAIL with exit code 0/1 so the orchestrator only starts caffeinate +
  /loop after the network is actually good.

.PARAMETER Ssid
  Which cached hotspot to use. Defaults to the 'default' in hotspots.json (miguel).

.PARAMETER VerifyOnly
  Skip all network changes; just run the DNS/internet/API verification against
  whatever the laptop is currently connected to. Safe, read-only.

.PARAMETER SkipCorpManual
  Do not flip the corp profile to manual connectionmode. (Default is to flip it,
  so Windows won't roam back to corp WiFi while you're still in the building.)

.PARAMETER Quiet
  Suppress the banner; still prints the final PASS/FAIL line.

.OUTPUTS
  Exit code 0 = PASS (API reachable). Exit code 1 = FAIL (with reason printed).
#>
[CmdletBinding()]
param(
  [string]$Ssid,
  [switch]$VerifyOnly,
  [switch]$SkipCorpManual,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfgPath   = Join-Path $scriptDir 'hotspots.json'

function Say     ($m) { if (-not $Quiet) { Write-Host $m } }
function Ok      ($m) { Write-Host "  [OK]   $m"   -ForegroundColor Green }
function Warn    ($m) { Write-Host "  [WARN] $m"   -ForegroundColor Yellow }
function Failure ($m) { Write-Host "  [FAIL] $m"   -ForegroundColor Red }

# ---- load cache ----------------------------------------------------------
if (-not (Test-Path $cfgPath)) { Failure "hotspots.json not found at $cfgPath"; exit 1 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
if (-not $Ssid) { $Ssid = $cfg.default }
$corp = $cfg.corpProfile

Say ""
Say "=== commute preflight ===  target hotspot: '$Ssid'   corp profile: '$corp'"
Say ""

function Get-CurrentSsid {
  $out = netsh wlan show interfaces 2>$null
  $line = $out | Select-String '^\s*SSID\s*:\s*(.+)$' | Select-Object -First 1
  if ($line) { return ($line.Matches[0].Groups[1].Value).Trim() }
  return $null
}

# ---- network switch (skipped in -VerifyOnly) -----------------------------
if (-not $VerifyOnly) {
  $hs = $cfg.hotspots.$Ssid
  if (-not $hs) { Failure "no cached hotspot named '$Ssid' in hotspots.json"; exit 1 }

  # 1. ensure a WLAN profile exists for the hotspot; create from cache if missing
  $profiles = (netsh wlan show profiles) | Out-String
  if ($profiles -notmatch [regex]::Escape($Ssid)) {
    Say "-> no saved profile for '$Ssid'; creating one from cached password"
    $xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$($hs.ssid)</name>
  <SSIDConfig><SSID><name>$($hs.ssid)</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM><security>
    <authEncryption><authentication>WPA2PSK</authentication><encryption>AES</encryption><useOneX>false</useOneX></authEncryption>
    <sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$($hs.password)</keyMaterial></sharedKey>
  </security></MSM>
</WLANProfile>
"@
    $tmp = Join-Path $env:TEMP "commute-$($hs.ssid).xml"
    $xml | Out-File -FilePath $tmp -Encoding utf8 -Force
    netsh wlan add profile filename="$tmp" user=current | Out-Null
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Ok "profile '$Ssid' created"
  }

  # 2. connect to the hotspot if not already on it
  if ((Get-CurrentSsid) -ne $Ssid) {
    Say "-> connecting to '$Ssid'..."
    netsh wlan connect name="$Ssid" ssid="$Ssid" | Out-Null
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-CurrentSsid) -ne $Ssid -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 800 }
    if ((Get-CurrentSsid) -eq $Ssid) { Ok "connected to '$Ssid'" }
    else {
      Failure "could not connect to '$Ssid'. Is the iPhone Personal Hotspot screen open and 'Allow Others to Join' ON?"
      exit 1
    }
  } else { Ok "already connected to '$Ssid'" }

  # 3. stop corp WiFi from auto-roaming back while still in range
  if (-not $SkipCorpManual) {
    try {
      netsh wlan set profileparameter name="$corp" connectionmode=manual | Out-Null
      Ok "corp profile '$corp' set to manual (won't roam back)"
    } catch { Warn "could not set '$corp' to manual: $($_.Exception.Message)" }
  }
}

# ---- VERIFY (always) -----------------------------------------------------
Say ""
Say "--- verification ---"
$cur = Get-CurrentSsid
if ($cur) { Ok "current SSID: $cur" } else { Warn "no SSID detected" }

$pass = $true

# DNS resolution
try {
  $ips = [System.Net.Dns]::GetHostAddresses('api.anthropic.com')
  Ok "DNS resolves api.anthropic.com ($($ips.Count) addr)"
} catch { Failure "DNS resolution failed: $($_.Exception.Message)"; $pass = $false }

# raw internet
try {
  if (Test-Connection -ComputerName 1.1.1.1 -Count 2 -Quiet) { Ok "raw internet OK (ping 1.1.1.1)" }
  else { Failure "ping 1.1.1.1 failed - no usable internet"; $pass = $false }
} catch { Failure "ping error: $($_.Exception.Message)"; $pass = $false }

# Anthropic API reachability (any HTTP status back = reachable; 401/400 expected)
try {
  $code = $null
  try {
    $resp = Invoke-WebRequest -Uri 'https://api.anthropic.com/v1/messages' -Method POST `
            -TimeoutSec 15 -UseBasicParsing -Body '{}' -ContentType 'application/json'
    $code = [int]$resp.StatusCode
  } catch [System.Net.WebException] {
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    else { throw }
  }
  if ($code) { Ok "api.anthropic.com reachable (HTTP $code)" }
  else { Failure "no HTTP response from api.anthropic.com"; $pass = $false }
} catch { Failure "api.anthropic.com unreachable: $($_.Exception.Message)"; $pass = $false }

Say ""
if ($pass) {
  Write-Host "PREFLIGHT PASS - safe to caffeinate + loop." -ForegroundColor Green
  exit 0
} else {
  Write-Host "PREFLIGHT FAIL - do NOT close the lid yet (see [FAIL] lines above)." -ForegroundColor Red
  exit 1
}
