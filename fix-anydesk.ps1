<#
    AnyDesk Block Remover - Windows
    --------------------------------------------------------------
    Recovers a personal AnyDesk install from the free-tier
    "commercial use suspected / session ended" block by resetting
    the local AnyDesk ID, while preserving your saved PC IDs
    (the address book / favorites stored in user.conf).

    Repo:    https://github.com/trongio/anydesk_block_remove
    License: MIT
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Yes,      # skip the confirmation prompt
    [switch]$NoBackup  # do not create a backup before deleting
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------------------------
#  Self-elevate: relaunch as Administrator if we are not already.
# ----------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] `
            [Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n  Administrator rights are required. Relaunching elevated..." -ForegroundColor Yellow

    # When invoked via `irm ... | iex` there is no file on disk, so persist
    # ourselves to a temp file first, then relaunch that elevated.
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = Join-Path $env:TEMP 'fix-anydesk.ps1'
        $MyInvocation.MyCommand.Definition | Set-Content -Path $scriptPath -Encoding UTF8
    }

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$scriptPath`"")
    if ($Yes)      { $argList += '-Yes' }
    if ($NoBackup) { $argList += '-NoBackup' }

    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    return
}

# ----------------------------------------------------------------------
#  TUI helpers
# ----------------------------------------------------------------------
$ESC = [char]27
function C($code, $text) { "$ESC[${code}m$text$ESC[0m" }

function Write-Banner {
    $cyan = '38;5;45'
    Clear-Host
    Write-Host ""
    Write-Host (C $cyan "    ___              ____            __  ")
    Write-Host (C $cyan "   /   |  ____  __  / __ \___  _____/ /__")
    Write-Host (C $cyan "  / /| | / __ \/ / / / / / _ \/ ___/ //_/")
    Write-Host (C $cyan " / ___ |/ / / / /_/ / /_/ /  __(__  ) ,<  ")
    Write-Host (C $cyan "/_/  |_/_/ /_/\__, /_____/\___/____/_/|_| ")
    Write-Host (C $cyan "             /____/  BLOCK REMOVER" )
    Write-Host ""
    Write-Host (C '38;5;240' "  Resets your AnyDesk ID to lift the free-tier block.")
    Write-Host (C '38;5;240' "  https://github.com/trongio/anydesk_block_remove")
    Write-Host ""
}

function Step($text)  { Write-Host ("  " + (C '38;5;45' ([string][char]0x279C + ' ')) + $text) }
function Ok($text)    { Write-Host ("    " + (C '38;5;82' ([string][char]0x2714 + ' ')) + (C '38;5;250' $text)) }
function Warn($text)  { Write-Host ("    " + (C '38;5;214' ([string][char]0x26A0 + ' ')) + (C '38;5;222' $text)) }
function Skip($text)  { Write-Host ("    " + (C '38;5;240' ([string][char]0x00B7 + ' ')) + (C '38;5;240' $text)) }
function Rule()       { Write-Host (C '38;5;240' ("  " + ([string][char]0x2500 * 50))) }

# ----------------------------------------------------------------------
#  Main
# ----------------------------------------------------------------------
Write-Banner

# Config locations on Windows.
$confDirs = @(
    (Join-Path $env:ProgramData 'AnyDesk'),
    (Join-Path $env:APPDATA    'AnyDesk')
)

# Files that hold the machine identity / block state - safe to delete.
# These are what get regenerated to give you a fresh, unblocked ID.
$killFiles = @(
    'service.conf', 'system.conf',
    'ad_svc.trace', 'ad.trace', 'connection_trace.txt'
)

# Files we explicitly PRESERVE - these hold your saved PC IDs / favorites.
$keepFiles = @('user.conf')

Warn "Your saved PC IDs live in 'user.conf' (the address book / favorites)."
Warn "This tool keeps that file, but RESET IDs CANNOT BE GUARANTEED - please"
Warn "note down any IDs/aliases you rely on before continuing, just in case."
Write-Host ""

if (-not $Yes) {
    $ans = Read-Host "  Proceed with the AnyDesk reset? [y/N]"
    if ($ans -notmatch '^(y|yes)$') {
        Write-Host (C '38;5;240' "`n  Cancelled. Nothing was changed.`n")
        return
    }
}
Write-Host ""
Rule

# 1. Stop AnyDesk (service + processes) so files are unlocked.
Step "Stopping AnyDesk service and processes"
$svc = Get-Service -Name 'AnyDesk*' -ErrorAction SilentlyContinue
foreach ($s in $svc) {
    if ($s.Status -ne 'Stopped') {
        Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        Ok "Stopped service: $($s.Name)"
    }
}
$procs = Get-Process -Name 'AnyDesk' -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Ok "Closed $($procs.Count) AnyDesk process(es)"
} else {
    Skip "No running AnyDesk processes"
}
Start-Sleep -Milliseconds 800

# 2. Back up everything first (unless disabled).
if (-not $NoBackup) {
    $stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $env:USERPROFILE "AnyDesk-backup-$stamp"
    Step "Backing up current config to:"
    Write-Host (C '38;5;240' "      $backupDir")
    foreach ($d in $confDirs) {
        if (Test-Path $d) {
            $dest = Join-Path $backupDir (Split-Path $d -Leaf)
            Copy-Item -Path $d -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
            Ok "Backed up $d"
        }
    }
}

# 3. Delete the identity/block files, preserving the saved-IDs file.
Step "Resetting AnyDesk identity (saved IDs preserved)"
$deleted = 0
foreach ($d in $confDirs) {
    if (-not (Test-Path $d)) { continue }
    foreach ($f in $killFiles) {
        $p = Join-Path $d $f
        if (Test-Path $p) {
            Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
            Ok "Removed $f  ($(Split-Path $d -Leaf))"
            $deleted++
        }
    }
    foreach ($k in $keepFiles) {
        if (Test-Path (Join-Path $d $k)) {
            Skip "Kept $k  ($(Split-Path $d -Leaf))  <- your saved PC IDs"
        }
    }
}
if ($deleted -eq 0) {
    Warn "No identity files found - is AnyDesk installed for this user?"
}

# 4. Restart the service so a fresh ID is generated.
Step "Restarting AnyDesk service"
foreach ($s in $svc) {
    Start-Service -Name $s.Name -ErrorAction SilentlyContinue
    Ok "Started service: $($s.Name)"
}

Rule
Write-Host ""
Write-Host ("  " + (C '38;5;82' ([string][char]0x2714 + ' Done!')))
Write-Host (C '38;5;250' "  Open AnyDesk - it should show a NEW ID and the block should be gone.")
Write-Host (C '38;5;250' "  Your saved PC IDs (favorites) were left untouched.")
if (-not $NoBackup) {
    Write-Host (C '38;5;240' "  A full backup was saved in your user folder if you need to restore.")
}
Write-Host ""
Read-Host "  Press Enter to close"
