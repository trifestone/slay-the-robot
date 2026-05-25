#Requires -Version 5.1
<#
.SYNOPSIS
    License audit checker for MyGame repository.

.DESCRIPTION
    Verifies that required license/attribution files are present and contain
    the expected attribution strings. Exits 0 on success, 1 on any failure.
    Run from any directory; paths are resolved relative to this script's location.

.EXAMPLE
    pwsh -File tools\check_license.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root as the parent of the tools/ directory
$repoRoot = Split-Path -Parent $PSScriptRoot

$failed = $false

function Fail {
    param([string]$Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
    $script:failed = $true
}

function Pass {
    param([string]$Message)
    Write-Host "OK  : $Message" -ForegroundColor Green
}

# --- Check 1: src/LICENSE exists and is non-empty ---
$licensePath = Join-Path $repoRoot "src\LICENSE"
if (-not (Test-Path $licensePath)) {
    Fail "src/LICENSE not found at: $licensePath"
} else {
    $licenseContent = Get-Content $licensePath -Raw
    if ([string]::IsNullOrWhiteSpace($licenseContent)) {
        Fail "src/LICENSE exists but is empty"
    } else {
        Pass "src/LICENSE exists and is non-empty"
    }
}

# --- Check 2: NOTICE exists at repo root ---
$noticePath = Join-Path $repoRoot "NOTICE"
if (-not (Test-Path $noticePath)) {
    Fail "NOTICE file not found at repo root: $noticePath"
} else {
    $noticeContent = Get-Content $noticePath -Raw

    # --- Check 2a: NOTICE contains "Slay-The-Robot" ---
    if ($noticeContent -notmatch 'Slay-The-Robot') {
        Fail "NOTICE does not contain 'Slay-The-Robot'"
    } else {
        Pass "NOTICE contains 'Slay-The-Robot'"
    }

    # --- Check 2b: NOTICE contains "GdUnit4" ---
    if ($noticeContent -notmatch 'GdUnit4') {
        Fail "NOTICE does not contain 'GdUnit4'"
    } else {
        Pass "NOTICE contains 'GdUnit4'"
    }

    # --- Check 2c: NOTICE contains "Godot" ---
    if ($noticeContent -notmatch 'Godot') {
        Fail "NOTICE does not contain 'Godot'"
    } else {
        Pass "NOTICE contains 'Godot'"
    }
}

# --- Check 3: src/addons/gdUnit4/ exists ---
$gdUnit4Path = Join-Path $repoRoot "src\addons\gdUnit4"
if (-not (Test-Path $gdUnit4Path -PathType Container)) {
    Fail "src/addons/gdUnit4/ directory not found at: $gdUnit4Path"
} else {
    Pass "src/addons/gdUnit4/ directory exists"
}

# --- Final result ---
if ($failed) {
    Write-Host ""
    Write-Host "License audit FAILED. See errors above." -ForegroundColor Red
    exit 1
} else {
    Write-Host ""
    Write-Host "License audit OK" -ForegroundColor Green
    exit 0
}
