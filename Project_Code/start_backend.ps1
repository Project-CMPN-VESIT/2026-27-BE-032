# DiabeticAI Backend Launcher
# Run this script from ANY directory — it always starts from the correct location.
#
# Usage:
#   .\start_backend.ps1
#
# The backend must be started from Project_Code\ (the parent of backend\)
# so that Python can resolve "from backend.xxx import ..." imports.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DiabeticAI FastAPI Backend Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Working dir : $ScriptDir"
Write-Host "  Module      : backend.app:app"
Write-Host "  URL         : http://127.0.0.1:8000"
Write-Host "  Swagger     : http://127.0.0.1:8000/docs"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set PYTHONPATH so 'backend' package is always discoverable
$env:PYTHONPATH = $ScriptDir

python -m uvicorn backend.app:app --host 0.0.0.0 --port 8000 --reload

