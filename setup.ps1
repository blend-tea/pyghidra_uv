#Requires -Version 5.1
<#
.SYNOPSIS
    PyGhidra (uv) setup script
.DESCRIPTION
    Copies pyghidraRunUv.bat and pyghidra_launcher_uv.py into the Ghidra
    installation directory and registers a Start Menu shortcut for the
    current user.
.PARAMETER GhidraDir
    Ghidra installation directory.
#>
param(
    [string]$GhidraDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot

# ---- Helper functions ----

function Read-NonEmpty {
    param([string]$Prompt)
    do {
        $val = Read-Host $Prompt
    } while ([string]::IsNullOrWhiteSpace($val))
    return $val.Trim()
}

# ---- Resolve Ghidra installation directory ----

Write-Host ''
Write-Host '=== PyGhidra (uv) Setup ===' -ForegroundColor Cyan
Write-Host ''

if ([string]::IsNullOrWhiteSpace($GhidraDir)) {
    # Interactive mode: prompt the user
    do {
        $GhidraDir = Read-NonEmpty 'Enter the Ghidra installation directory'
        $GhidraDir = $GhidraDir.Trim('"').Trim("'")

        if (-not (Test-Path $GhidraDir -PathType Container)) {
            Write-Warning "Directory not found: $GhidraDir"
            $GhidraDir = ''
            continue
        }
        if (-not (Test-Path (Join-Path $GhidraDir 'Ghidra') -PathType Container)) {
            Write-Warning "'Ghidra' subfolder not found. Please specify a valid Ghidra installation directory."
            $GhidraDir = ''
        }
    } while ([string]::IsNullOrWhiteSpace($GhidraDir))
} else {
    Write-Host "Ghidra installation directory: $GhidraDir"
}

# ---- Resolve destination paths ----

$SupportDst         = Join-Path $GhidraDir 'support'
$PyGhidraSupportDst = Join-Path $GhidraDir 'Ghidra\Features\PyGhidra\support'

$SrcBat      = Join-Path $ScriptDir 'pyghidraRunUv.bat'
$SrcLauncher = Join-Path $ScriptDir 'pyghidra_launcher_uv.py'
$IconPath    = Join-Path $GhidraDir 'support\ghidra.ico'

# ---- Verify source files exist ----

foreach ($f in @($SrcBat, $SrcLauncher)) {
    if (-not (Test-Path $f)) {
        Write-Error "Source file not found: $f"
        exit 1
    }
}

# ---- Copy files ----

Write-Host ''
Write-Host '--- Copying files ---' -ForegroundColor Cyan

foreach ($dir in @($SupportDst, $PyGhidraSupportDst)) {
    if (-not (Test-Path $dir -PathType Container)) {
        Write-Host "  Created: $dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Copy-Item -Path $SrcBat      -Destination $SupportDst         -Force
Write-Host "  Copied: $SrcBat -> $SupportDst"

Copy-Item -Path $SrcLauncher -Destination $PyGhidraSupportDst -Force
Write-Host "  Copied: $SrcLauncher -> $PyGhidraSupportDst"

# ---- Create Start Menu shortcut (current user) ----

Write-Host ''
Write-Host '--- Registering Start Menu shortcut ---' -ForegroundColor Cyan

# Per-user Start Menu (APPDATA\...\Start Menu\Programs)
$StartMenuBase = [System.Environment]::GetFolderPath('StartMenu')

$ShortcutDir = Join-Path $StartMenuBase 'Programs\Ghidra'
if (-not (Test-Path $ShortcutDir -PathType Container)) {
    New-Item -ItemType Directory -Path $ShortcutDir -Force | Out-Null
}

$ShortcutPath = Join-Path $ShortcutDir 'PyGhidra.lnk'
$TargetBat    = Join-Path $SupportDst 'pyghidraRunUv.bat'

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath       = $TargetBat
$Shortcut.WorkingDirectory = $SupportDst
$Shortcut.Description      = 'PyGhidra (uv)'

if (Test-Path $IconPath) {
    $Shortcut.IconLocation = "$IconPath,0"
} else {
    Write-Warning "Icon file not found: $IconPath (using default icon)"
}

$Shortcut.Save()
Write-Host "  Shortcut created: $ShortcutPath"

# ---- Done ----

Write-Host ''
Write-Host '=== Setup complete ===' -ForegroundColor Green
Write-Host ''
Write-Host "  - pyghidraRunUv.bat       -> $SupportDst"
Write-Host "  - pyghidra_launcher_uv.py -> $PyGhidraSupportDst"
Write-Host "  - Start Menu shortcut     -> $ShortcutPath"
Write-Host '  - Scope: current user only'
Write-Host ''
