# ============================================================
# DiabeticAI - Full Stack Launcher
# Starts FastAPI backend + Cloudflare Tunnel in one window.
#
# USAGE (run from any location):
#   cd "C:\Capstone Project\Capstone_Project_Diabetes_App\Project_Code"
#   .\start_full_stack.ps1
#
# What it does:
#   1. Starts uvicorn backend (port 8000) in a background job
#   2. Waits for backend to be healthy
#   3. Launches cloudflared tunnel and captures the HTTPS URL
#   4. Updates constants.dart with the live public URL
#   5. Prints Swagger docs URL and all public endpoint URLs
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$BackendDir   = Join-Path $ScriptDir "backend"
$CloudflaredExe = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
$ConstantsFile = Join-Path $ScriptDir "DiabeticAI_Flutter\lib\utils\constants.dart"
$PythonExe   = "python"

# ── Banner ──────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  DiabeticAI Full Stack Launcher" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Backend   : http://127.0.0.1:8000"
Write-Host "  Swagger   : http://127.0.0.1:8000/docs"
Write-Host "  Tunnel    : Will be assigned by Cloudflare"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Start backend in background job ──────────────────
$env:PYTHONPATH = $ScriptDir
$env:KERAS_HOME  = "$BackendDir\.keras_cache"
$env:MPLCONFIGDIR = "$BackendDir\.mpl_cache"

Write-Host "[1/4] Starting FastAPI backend..." -ForegroundColor Yellow
$backendJob = Start-Job -ScriptBlock {
    param($dir, $pythonExe)
    $env:PYTHONPATH = $dir
    $env:KERAS_HOME = "$dir\backend\.keras_cache"
    $env:MPLCONFIGDIR = "$dir\backend\.mpl_cache"
    Set-Location $dir
    & $pythonExe -m uvicorn backend.app:app --host 127.0.0.1 --port 8000
} -ArgumentList $ScriptDir, $PythonExe

# ── Step 2: Wait for /health ──────────────────────────────────
Write-Host "[2/4] Waiting for backend to become healthy..." -ForegroundColor Yellow
$healthy = $false
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -Method Get -TimeoutSec 2
        if ($r.status -eq "ok") {
            Write-Host "      Backend HEALTHY: status=$($r.status)" -ForegroundColor Green
            $healthy = $true
            break
        }
    } catch {}
}
if (-not $healthy) {
    Write-Host "ERROR: Backend did not become healthy in 40s." -ForegroundColor Red
    Stop-Job $backendJob
    exit 1
}

# ── Step 3: Start Cloudflare Tunnel and capture URL ───────────
Write-Host "[3/4] Starting Cloudflare Tunnel..." -ForegroundColor Yellow
$cfProc = Start-Process -FilePath $CloudflaredExe `
    -ArgumentList "tunnel", "--url", "http://127.0.0.1:8000" `
    -PassThru -NoNewWindow -RedirectStandardOutput "$ScriptDir\.cf_tunnel_log.txt" -RedirectStandardError "$ScriptDir\.cf_tunnel_err.txt"

$tunnelUrl = $null
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    if (Test-Path "$ScriptDir\.cf_tunnel_log.txt") {
        $logContent = Get-Content "$ScriptDir\.cf_tunnel_log.txt" -Raw -ErrorAction SilentlyContinue
        if ($logContent -match "(https://[a-zA-Z0-9-]+\.trycloudflare\.com)") {
            $tunnelUrl = $Matches[1]
            break
        }
    }
    if (Test-Path "$ScriptDir\.cf_tunnel_err.txt") {
        $errContent = Get-Content "$ScriptDir\.cf_tunnel_err.txt" -Raw -ErrorAction SilentlyContinue
        if ($errContent -match "(https://[a-zA-Z0-9-]+\.trycloudflare\.com)") {
            $tunnelUrl = $Matches[1]
            break
        }
    }
}

if (-not $tunnelUrl) {
    Write-Host "ERROR: Could not capture Cloudflare Tunnel URL within 30s." -ForegroundColor Red
    $cfProc.Kill()
    Stop-Job $backendJob
    exit 1
}

# ── Step 4: Update constants.dart ─────────────────────────────
Write-Host "[4/4] Updating Flutter constants.dart with live URL..." -ForegroundColor Yellow
if (Test-Path $ConstantsFile) {
    $content = Get-Content $ConstantsFile -Raw
    $updated = $content -replace 'static const String baseUrl = ".*?";', "static const String baseUrl = `"$tunnelUrl`";"
    Set-Content -Path $ConstantsFile -Value $updated -Encoding UTF8
    Write-Host "      Updated constants.dart -> baseUrl = `"$tunnelUrl`"" -ForegroundColor Green
} else {
    Write-Host "      WARNING: constants.dart not found at $ConstantsFile" -ForegroundColor DarkYellow
}

# ── Summary ───────────────────────────────────────────────────
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  DiabeticAI Stack is LIVE!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Local Swagger  : http://127.0.0.1:8000/docs"
Write-Host "  Public Health  : $tunnelUrl/health"
Write-Host "  Public Assess  : $tunnelUrl/predict/assessment"
Write-Host "  Public Retina  : $tunnelUrl/predict/retina"
Write-Host "  Public Foot    : $tunnelUrl/predict/foot"
Write-Host "  Public Final   : $tunnelUrl/predict/final"
Write-Host ""
Write-Host "  constants.dart already updated with the public URL above."
Write-Host "  Rebuild Flutter Web/Android to use the new URL."
Write-Host ""
Write-Host "  Press Ctrl+C to stop the tunnel. Backend job ID: $($backendJob.Id)"
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tunnel is running. Press Ctrl+C to stop..." -ForegroundColor Gray

# Keep script alive while tunnel is running
try {
    $cfProc.WaitForExit()
} finally {
    Stop-Job $backendJob
    Remove-Job $backendJob -Force -ErrorAction SilentlyContinue
    Remove-Item "$ScriptDir\.cf_tunnel_log.txt", "$ScriptDir\.cf_tunnel_err.txt" -ErrorAction SilentlyContinue
}

