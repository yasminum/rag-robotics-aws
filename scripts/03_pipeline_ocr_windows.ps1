# =====================================================================
# 03_pipeline_ocr_windows.ps1
# Pipeline OCR que se ejecuta LOCALMENTE en Windows (sin WSL ni AWS EC2)
# Procesa todos los PDFs escaneados de una carpeta y sube a S3
# =====================================================================
# USO:
#   .\scripts\03_pipeline_ocr_windows.ps1 -SourcePath "C:\ruta\escaneados"
# =====================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [string]$Bucket = "robotic-paper-rag",
    [string]$Region = "us-east-2",
    [string]$Languages = "spa+eng"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

function Sanitize-Name($name) {
    $clean = $name -replace '\s+', '_'
    $clean = $clean -replace '[()]', '_'
    $clean = $clean -replace '[\[\]]', '_'
    $clean = $clean.Normalize([System.Text.NormalizationForm]::FormD)
    $cleanBytes = [System.Text.Encoding]::ASCII.GetBytes($clean.ToCharArray())
    $clean = [System.Text.Encoding]::ASCII.GetString($cleanBytes)
    $clean = $clean -replace '_+', '_'
    $clean = $clean.TrimEnd('_')
    return $clean
}

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  PIPELINE OCR Local - Windows" -ForegroundColor Yellow
Write-Host "  Source: $SourcePath" -ForegroundColor Yellow
Write-Host "  Bucket: s3://$Bucket/books/" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# Verificar dependencias
foreach ($cmd in @("tesseract", "ocrmypdf", "aws")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Err "$cmd no esta instalado. Ejecuta primero:"
        Write-Host "  .\scripts\02_setup_ocr_windows.ps1"
        exit 1
    }
}
Write-OK "Dependencias OK"

# ---------------------------------------------------------
# 1. Listar PDFs
# ---------------------------------------------------------
Write-Step "Buscando PDFs en $SourcePath"

$pdfFiles = Get-ChildItem -Path $SourcePath -Filter *.pdf -File -Recurse
$total = $pdfFiles.Count
Write-Host "PDFs encontrados: $total"

if ($total -eq 0) {
    Write-Err "No hay PDFs en $SourcePath"
    exit 1
}

# ---------------------------------------------------------
# 2. Crear carpeta temporal de salida
# ---------------------------------------------------------
$workDir = Join-Path $env:TEMP "rag_ocr_work_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
New-Item -ItemType Directory -Path "$workDir\output" -Force | Out-Null
Write-OK "Carpeta temporal: $workDir"

# ---------------------------------------------------------
# 3. Procesar cada PDF
# ---------------------------------------------------------
Write-Step "Procesando PDFs con OCR"

$success = 0
$failed = 0
$failedFiles = @()

$i = 0
foreach ($pdf in $pdfFiles) {
    $i++
    $cleanName = Sanitize-Name $pdf.Name
    $outName = [System.IO.Path]::GetFileNameWithoutExtension($cleanName) + "_ocr.pdf"
    $outPath = Join-Path "$workDir\output" $outName
    $logPath = Join-Path $workDir "$cleanName.log"

    Write-Host "`n[$i/$total] $($pdf.Name)" -ForegroundColor White
    Write-Host "  -> $cleanName" -ForegroundColor Gray

    $cmd = "ocrmypdf -l $Languages --force-ocr --deskew --clean --optimize 1 --jobs 2 `"$($pdf.FullName)`" `"$outPath`" 2>&1 | Tee-Object -FilePath `"$logPath`""

    try {
        Invoke-Expression $cmd | Out-Null
        if (Test-Path $outPath) {
            $sizeInKB = [math]::Round($pdf.Length / 1KB, 1)
            $sizeOutKB = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
            Write-OK "OK: $sizeInKB KB -> $sizeOutKB KB"
            $success++
        } else {
            Write-Err "No se genero el archivo de salida"
            $failed++
            $failedFiles += $pdf.Name
        }
    } catch {
        Write-Err "Error: $_"
        $failed++
        $failedFiles += $pdf.Name
    }
}

# ---------------------------------------------------------
# 4. Subir a S3
# ---------------------------------------------------------
Write-Step "Subiendo PDFs procesados a S3"

if ($success -gt 0) {
    $outputFiles = Get-ChildItem -Path "$workDir\output" -Filter *.pdf -File
    foreach ($outFile in $outputFiles) {
        $s3Uri = "s3://$Bucket/books/$($outFile.Name)"
        Write-Host "  Subiendo: $($outFile.Name)" -NoNewline
        aws s3 cp $outFile.FullName $s3Uri --region $Region 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " - OK" -ForegroundColor Green
        } else {
            Write-Host " - FALLO" -ForegroundColor Red
        }
    }
    Write-OK "Upload completado"
} else {
    Write-Err "No hay PDFs procesados para subir"
}

# ---------------------------------------------------------
# 5. Limpiar temporales
# ---------------------------------------------------------
Write-Step "Limpiando archivos temporales"
Remove-Item -Path $workDir -Recurse -Force -ErrorAction SilentlyContinue
Write-OK "Limpieza completada"

# ---------------------------------------------------------
# Resumen
# ---------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN PIPELINE OCR"
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Total PDFs      : $total"
Write-Host "  Procesados OK   : $success" -ForegroundColor Green
Write-Host "  Fallidos        : $failed" -ForegroundColor Red
if ($failedFiles) {
    Write-Host "`n  Archivos fallidos:" -ForegroundColor Red
    foreach ($f in $failedFiles) { Write-Host "    - $f" }
}
Write-Host ""
Write-Host "  PROXIMO PASO:"
Write-Host "    1. Amazon Bedrock → Knowledge Bases"
Write-Host "    2. Entra a tu KB → Data source → Sync"
Write-Host "    3. Espera estado 'Available'"
Write-Host "    4. Prueba en la pestana Test"
Write-Host "================================================"
