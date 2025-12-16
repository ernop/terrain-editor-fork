<#
.SYNOPSIS
    Run all linting tools for the Terrain Editor project.

.DESCRIPTION
    This script runs all configured linters:
    - selene (Lua linter)
    - stylua --check (Lua formatter check)
    - ast-grep scan (structural pattern linter)

    Exit code is non-zero if any linter fails.

.PARAMETER Fix
    When specified, runs stylua in fix mode instead of check mode.

.PARAMETER AstGrepOnly
    When specified, only runs ast-grep scan.

.PARAMETER SeleneOnly
    When specified, only runs selene.

.PARAMETER Verbose
    Show verbose output from linters.

.EXAMPLE
    .\lint.ps1
    # Run all linters in check mode

.EXAMPLE
    .\lint.ps1 -Fix
    # Run linters and auto-fix stylua issues

.EXAMPLE
    .\lint.ps1 -AstGrepOnly
    # Only run ast-grep structural linting
#>

param(
    [switch]$Fix,
    [switch]$AstGrepOnly,
    [switch]$SeleneOnly,
    [switch]$StyluaOnly,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"
$exitCode = 0

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Check for required tools
$missingTools = @()

if (-not $AstGrepOnly) {
    if (-not (Test-Command "selene")) {
        $missingTools += "selene (install: cargo install selene or aftman add Kampfkarren/selene)"
    }
    if (-not (Test-Command "stylua")) {
        $missingTools += "stylua (install: cargo install stylua or aftman add JohnnyMorganz/StyLua)"
    }
}

if (-not $SeleneOnly -and -not $StyluaOnly) {
    # Check for ast-grep (can be 'ast-grep' or 'sg')
    if (-not (Test-Command "ast-grep") -and -not (Test-Command "sg")) {
        $missingTools += "ast-grep (install: npm install -g @ast-grep/cli OR pip install ast-grep-cli OR cargo install ast-grep)"
    }
}

if ($missingTools.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing required tools:" -ForegroundColor Red
    foreach ($tool in $missingTools) {
        Write-Host "  • $tool" -ForegroundColor Yellow
    }
    Write-Host ""
    exit 1
}

# Determine ast-grep command
$astGrepCmd = if (Test-Command "ast-grep") { "ast-grep" } else { "sg" }

# ─────────────────────────────────────────────────────────────────────────────
# SELENE - Lua Linter
# ─────────────────────────────────────────────────────────────────────────────
if (-not $AstGrepOnly -and -not $StyluaOnly) {
    Write-Header "Running Selene (Lua Linter)"
    
    $seleneArgs = @(".")
    if ($Verbose) {
        $seleneArgs += "--display-style=rich"
    }
    
    & selene @seleneArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Selene found issues" -ForegroundColor Red
        $exitCode = 1
    } else {
        Write-Host "  ✓ Selene passed" -ForegroundColor Green
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# STYLUA - Lua Formatter
# ─────────────────────────────────────────────────────────────────────────────
if (-not $AstGrepOnly -and -not $SeleneOnly) {
    Write-Header "Running StyLua (Lua Formatter)"
    
    if ($Fix) {
        Write-Host "  Mode: Fix" -ForegroundColor Yellow
        & stylua .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ StyLua encountered errors" -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "  ✓ StyLua formatting applied" -ForegroundColor Green
        }
    } else {
        Write-Host "  Mode: Check" -ForegroundColor Gray
        & stylua --check .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ StyLua found formatting issues (run with -Fix to auto-fix)" -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "  ✓ StyLua passed" -ForegroundColor Green
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# AST-GREP - Structural Pattern Linter
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SeleneOnly -and -not $StyluaOnly) {
    Write-Header "Running ast-grep (Structural Pattern Linter)"
    
    # Check if sgconfig.yml exists
    if (-not (Test-Path "sgconfig.yml")) {
        Write-Host "  ⚠ sgconfig.yml not found, skipping ast-grep" -ForegroundColor Yellow
    } else {
        $astGrepArgs = @("scan")
        if ($Verbose) {
            $astGrepArgs += "--json=false"
        }
        
        & $astGrepCmd @astGrepArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✗ ast-grep found structural issues" -ForegroundColor Red
            $exitCode = 1
        } else {
            Write-Host "  ✓ ast-grep passed" -ForegroundColor Green
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
if ($exitCode -eq 0) {
    Write-Host " All linters passed! ✓" -ForegroundColor Green
} else {
    Write-Host " Some linters failed. Fix the issues above. ✗" -ForegroundColor Red
}
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

exit $exitCode

