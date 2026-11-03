# =====================================================================
# 01_scrape_bibliografia.ps1
# Wrapper PowerShell que ejecuta el script Python de scraping arXiv
# =====================================================================
# USO:
#   .\scripts\01_scrape_bibliografia.ps1
# =====================================================================

$ErrorActionPreference = "Stop"

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  Scraper arXiv - RAG Robotics AWS" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# Verificar Python
if (-not (Get-Command python -ErrorAction SilentlyContinue) -and
    -not (Get-Command python3 -ErrorAction SilentlyContinue)) {
    Write-Host "[X] Python no esta instalado" -ForegroundColor Red
    Write-Host "  Descarga de: https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

$pythonCmd = if (Get-Command python -ErrorAction SilentlyContinue) { "python" } else { "python3" }
Write-Host "[OK] Usando: $pythonCmd" -ForegroundColor Green

# Ejecutar el script Python original (sigue siendo multiplataforma)
$scriptPath = Join-Path $PSScriptRoot "01_scrape_bibliografia.py"
if (-not (Test-Path $scriptPath)) {
    Write-Host "[X] No se encontro: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nEjecutando scraper...`n" -ForegroundColor Cyan
& $pythonCmd $scriptPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Scraper completado" -ForegroundColor Green
    Write-Host "  Papers descargados en: download\papers\"
    Write-Host "  CSV generado en: download\bibliografia_robots_ia.csv"
} else {
    Write-Host "`n[X] El scraper fallo" -ForegroundColor Red
    exit 1
}
