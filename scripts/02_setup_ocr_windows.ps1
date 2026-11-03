# =====================================================================
# 02_setup_ocr_windows.ps1
# Setup de OCRmyPDF + Tesseract en WINDOWS (sin WSL)
#
# En vez de usar EC2, instala Tesseract localmente en tu Windows
# y procesa los PDFs en tu PC (gratis, sin AWS)
# =====================================================================
# USO:
#   1. Abre PowerShell como ADMINISTRADOR
#   2. Ejecuta: .\scripts\02_setup_ocr_windows.ps1
# =====================================================================

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  Setup OCR Local - Windows (sin WSL ni AWS)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# ---------------------------------------------------------
# 1. Verificar/instalar Chocolatey
# ---------------------------------------------------------
Write-Step "Verificando gestor de paquetes Chocolatey"

if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))
    # Refrescar PATH
    $env:Path += ";$env:ALLUSERSPROFILE\chocolatey\bin"
} else {
    Write-OK "Chocolatey ya esta instalado"
}

# ---------------------------------------------------------
# 2. Instalar Tesseract OCR
# ---------------------------------------------------------
Write-Step "Instalando Tesseract OCR + idioma espanol"

if (-not (Get-Command tesseract -ErrorAction SilentlyContinue)) {
    choco install tesseract -y
    $env:Path += ";C:\Program Files\Tesseract-OCR"
} else {
    Write-OK "Tesseract ya esta instalado"
    # Asegurar que tiene el idioma espanol
    $langs = (tesseract --list-langs) 2>&1
    if ($langs -notmatch "spa") {
        Write-Host "Instalando paquete de idioma espanol..." -ForegroundColor Yellow
        choco upgrade tesseract -y --params "/Language:spa"
    }
}

Write-OK "Tesseract version: $((tesseract --version) 2>&1 | Select-Object -First 1)"
Write-Host "Idiomas disponibles:"
(tesseract --list-langs) 2>&1 | Select-String -Pattern "^(spa|eng)$" | ForEach-Object { Write-Host "  - $_" }

# ---------------------------------------------------------
# 3. Instalar Python y OCRmyPDF
# ---------------------------------------------------------
Write-Step "Instalando OCRmyPDF via pip"

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Python..." -ForegroundColor Yellow
    choco install python -y
    $env:Path += ";C:\Python311\;C:\Python311\Scripts\"
}

python -m pip install --upgrade pip
python -m pip install ocrmypdf

Write-OK "OCRmyPDF instalado"
Write-Host "Version: $((ocrmypdf --version) 2>&1 | Select-Object -First 1)"

# ---------------------------------------------------------
# 4. Verificar Ghostscript (dependencia de OCRmyPDF)
# ---------------------------------------------------------
Write-Step "Verificando Ghostscript"
if (-not (Get-Command gswin64c -ErrorAction SilentlyContinue)) {
    Write-Host "Instalando Ghostscript..." -ForegroundColor Yellow
    choco install ghostscript -y
    $env:Path += ";C:\Program Files\gs\gs10.03.0\bin"
}
Write-OK "Ghostscript listo"

# ---------------------------------------------------------
# 5. Verificar AWS CLI
# ---------------------------------------------------------
Write-Step "Verificando AWS CLI"
if (Get-Command aws -ErrorAction SilentlyContinue) {
    Write-OK "AWS CLI: $((aws --version) 2>&1)"
} else {
    Write-Host "Instalando AWS CLI..." -ForegroundColor Yellow
    choco install awscli -y
    $env:Path += ";C:\Program Files\Amazon\AWSCLIV2\"
    Write-OK "AWS CLI instalado (reinicia PowerShell para que tome el PATH)"
}
if (-not (Test-Path "$env:USERPROFILE\.aws\credentials")) {
    Write-Host "[!] No tienes credenciales AWS configuradas" -ForegroundColor Yellow
    Write-Host "    Ejecuta: aws configure"
    Write-Host "    Necesitas tu Access Key y Secret Key"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETADO!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximo paso: ejecuta el pipeline de OCR:"
Write-Host "  .\scripts\03_pipeline_ocr_windows.ps1 -SourcePath 'C:\ruta\a\tus\pdfs\escaneados'" -ForegroundColor White
Write-Host ""
Write-Host "NOTA: Cierra y vuelve a abrir PowerShell para que tome el PATH nuevo."
