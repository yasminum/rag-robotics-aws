# =====================================================================
# 04_upload_s3.ps1
# Sube archivos a S3 saneando nombres (sin espacios/acentos/parentesis)
# Version NATIVA de Windows PowerShell (sin WSL)
# =====================================================================
# USO:
#   .\scripts\04_upload_s3.ps1 -SourcePath "C:\Users\yurrego\OneDrive\Documentos\libros"
# =====================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [string]$Bucket = "robotic-paper-rag",
    [string]$Region  = "us-east-2"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

# Mapeo de extension -> carpeta destino en S3
$FolderMap = @{
    "pdf"  = "books/"
    "docx" = "books/"
    "pptx" = "classroom/"
    "ppt"  = "classroom/"
    "xlsx" = "classroom/"
    "txt"  = "classroom/"
    "md"   = "classroom/"
    "html" = "classroom/"
    "mlx"  = "unsupported/"
    "one"  = "unsupported/"
    "mat"  = "unsupported/"
}

function Sanitize-Name($name) {
    # Quitar espacios, parentesis, corchetes
    $clean = $name -replace '\s+', '_'
    $clean = $clean -replace '[()]', '_'
    $clean = $clean -replace '[\[\]]', '_'
    # Quitar acentos usando normalization
    $clean = $clean.Normalize([System.Text.NormalizationForm]::FormD)
    $cleanBytes = [System.Text.Encoding]::ASCII.GetBytes($clean.ToCharArray())
    $clean = [System.Text.Encoding]::ASCII.GetString($cleanBytes)
    # Colapsar dobles guiones bajos
    $clean = $clean -replace '_+', '_'
    # Quitar guion bajo al final si existe
    $clean = $clean.TrimEnd('_')
    return $clean
}

# ---------------------------------------------------------
# Verificar AWS CLI
# ---------------------------------------------------------
Write-Step "Verificando dependencias"

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Err "AWS CLI no esta instalado."
    Write-Host "  Descarga de: https://aws.amazon.com/cli/"
    Write-Host "  Despues ejecuta: aws configure"
    exit 1
}
Write-OK "AWS CLI detectado"

if (-not (Test-Path $SourcePath)) {
    Write-Err "La carpeta $SourcePath no existe"
    exit 1
}

# ---------------------------------------------------------
# Verificar bucket
# ---------------------------------------------------------
Write-Step "Verificando bucket S3"
try {
    aws s3 ls "s3://$Bucket/" --region $Region 2>$null | Out-Null
    Write-OK "Bucket accesible: s3://$Bucket"
} catch {
    Write-Err "No se puede acceder al bucket s3://$Bucket"
    Write-Host "  Crea el bucket con:"
    Write-Host "    aws s3api create-bucket --bucket $Bucket --region $Region --create-bucket-configuration LocationConstraint=$Region"
    exit 1
}

# ---------------------------------------------------------
# Crear carpetas en S3 (marcadores 0-byte)
# ---------------------------------------------------------
Write-Step "Creando carpetas en S3"
foreach ($folder in @("books", "papers", "classroom", "unsupported")) {
    aws s3api put-object --bucket $Bucket --key "$folder/" --region $Region 2>$null | Out-Null
}
Write-OK "Carpetas creadas"

# ---------------------------------------------------------
# Procesar cada archivo
# ---------------------------------------------------------
Write-Step "Procesando archivos de: $SourcePath"

$files = Get-ChildItem -Path $SourcePath -File -Recurse
$total = $files.Count
$uploadCount = 0
$skipCount = 0
$failCount = 0

foreach ($file in $files) {
    $ext = $file.Extension.TrimStart('.').ToLower()
    $cleanName = Sanitize-Name $file.Name
    $destFolder = if ($FolderMap.ContainsKey($ext)) { $FolderMap[$ext] } else { "unsupported/" }

    if ($destFolder -eq "unsupported/") {
        Write-Host "[SKIP] $($file.Name) (formato no soportado por Bedrock)" -ForegroundColor Yellow
        if ($ext -eq "mlx") {
            Write-Host "       Conviertelo a PDF desde MATLAB: Live Editor → Export → PDF" -ForegroundColor Gray
        } elseif ($ext -eq "one") {
            Write-Host "       Conviertelo a PDF desde OneNote: File → Export → PDF" -ForegroundColor Gray
        }
        $skipCount++
        continue
    }

    $s3Uri = "s3://$Bucket/$destFolder$cleanName"
    Write-Host "[UP]   $cleanName → $s3Uri"

    $tmpPath = Join-Path $env:TEMP $cleanName
    Copy-Item $file.FullName $tmpPath -Force

    try {
        aws s3 cp $tmpPath $s3Uri --region $Region 2>$null
        if ($LASTEXITCODE -eq 0) {
            $uploadCount++
        } else {
            Write-Err "Fallo al subir $($file.Name)"
            $failCount++
        }
    } catch {
        Write-Err "Error: $_"
        $failCount++
    } finally {
        Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------
# Resumen
# ---------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  RESUMEN DE SUBIDA"
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Total procesados     : $total"
Write-Host "  Subidos OK           : $uploadCount" -ForegroundColor Green
Write-Host "  Skip (no soportados) : $skipCount" -ForegroundColor Yellow
Write-Host "  Fallidos             : $failCount" -ForegroundColor Red
Write-Host ""
Write-Host "  Bucket: s3://$Bucket"
Write-Host ""
Write-Host "  PROXIMO PASO:"
Write-Host "    1. Amazon Bedrock → Knowledge Bases"
Write-Host "    2. Entra a tu KB → Data source → Sync"
Write-Host "    3. Espera estado 'Available' y prueba en Test"
Write-Host "================================================"
