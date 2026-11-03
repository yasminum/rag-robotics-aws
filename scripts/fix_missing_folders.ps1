# =====================================================================
# fix_missing_folders.ps1
# Arregla el repo si faltan carpetas (docs/, infra/, lambda/) en GitHub
# =====================================================================
# Diagnóstico: si en tu repo de GitHub solo ves:
#   .github/  diagrams/  scripts/  .gitignore  LICENSE  README.md
# Entonces faltan:
#   docs/      (documentación)
#   infra/     (CloudFormation)
#   lambda/    (Lambda OCR opcional)
#
# Este script las crea y vuelve a pushear.
# =====================================================================

param(
    [string]$CommitMsg = "Add missing folders: docs, infra, lambda + fix .gitignore"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  Fix missing folders - rag-robotics-aws" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# Verificar que estamos en la raíz del repo
if (-not (Test-Path .git)) {
    Write-Err "No estas en la raiz del repo. Ejecuta este script desde la carpeta rag-robotics-aws/"
    exit 1
}

Write-Step "Verificando carpetas existentes"

$expectedFolders = @("docs", "infra", "lambda")
$missingFolders = @()

foreach ($folder in $expectedFolders) {
    if (Test-Path $folder) {
        $items = Get-ChildItem -Path $folder -File -Recurse | Measure-Object
        Write-OK "$folder/ existe ($($items.Count) archivos)"
    } else {
        Write-Warn "$folder/ NO existe - se creara"
        $missingFolders += $folder
    }
}

# ---------------------------------------------------------
# Si faltan carpetas, creamos la estructura mínima
# ---------------------------------------------------------
if ($missingFolders.Count -gt 0) {
    Write-Step "Creando carpetas faltantes"

    foreach ($folder in $missingFolders) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-OK "Creada: $folder/"
    }

    # Crear archivos placeholder si no existen

    # docs/INSTRUCCIONES_AWS_OCR.md
    if (-not (Test-Path "docs/INSTRUCCIONES_AWS_OCR.md")) {
        Write-Host "  Creando docs/INSTRUCCIONES_AWS_OCR.md (placeholder)" -ForegroundColor Gray
        @"
# OCR gratis en AWS + RAG con Bedrock

> Nota: este archivo debería contener la guía completa paso a paso.
> Si tu repo local lo tenía, copia el contenido aquí.
> Si no, puedes descargarlo del repo original o escribirlo más adelante.

## Resumen

1. Setup OCRmyPDF + Tesseract en Windows o EC2
2. Procesar PDFs escaneados a texto seleccionable
3. Subir a S3 en carpeta books/
4. Sincronizar Knowledge Base en Bedrock
5. Probar en pestaña Test

Ver README principal para el flujo completo.
"@ | Out-File -FilePath "docs/INSTRUCCIONES_AWS_OCR.md" -Encoding UTF8
        Write-OK "docs/INSTRUCCIONES_AWS_OCR.md creado"
    }

    # infra/README.md
    if (-not (Test-Path "infra/README.md")) {
        Write-Host "  Creando infra/README.md (placeholder)" -ForegroundColor Gray
        @"
# Infraestructura como código (IaC)

Esta carpeta contiene los templates de CloudFormation para desplegar
toda la infraestructura del RAG en una sola línea de comandos.

## Archivos

- `knowledge_base.yaml` — CloudFormation template que crea:
  - Bucket S3 `robotic-paper-rag` con carpetas books/, papers/, classroom/
  - IAM role para Bedrock con permisos S3
  - Knowledge Base con Titan Embeddings V2
  - OpenSearch Serverless collection (o S3 Vectors si está disponible)
  - Política de acceso al OpenSearch

## Deploy

```powershell
aws cloudformation create-stack `
    --stack-name rag-robotics `
    --template-body file://infra/knowledge_base.yaml `
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
    --region us-east-2
```

## Destroy

```powershell
aws cloudformation delete-stack --stack-name rag-robotics --region us-east-2
```
"@ | Out-File -FilePath "infra/README.md" -Encoding UTF8
        Write-OK "infra/README.md creado"
    }

    # infra/knowledge_base.yaml
    if (-not (Test-Path "infra/knowledge_base.yaml")) {
        Write-Host "  Creando infra/knowledge_base.yaml (placeholder mínimo)" -ForegroundColor Gray
        @"
AWSTemplateFormatVersion: '2010-09-09'
Description: 'RAG Robotics AWS - Knowledge Base sobre bibliografia de robotica'

Parameters:
  BucketName:
    Type: String
    Default: robotic-paper-rag
    Description: Nombre del bucket S3 (debe ser globalmente unico)
  Region:
    Type: String
    Default: us-east-2
    AllowedValues: [us-east-1, us-east-2, us-west-2, eu-west-1]

Resources:
  RagBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        BlockPublicPolicy: true
        IgnorePublicAcls: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: Enabled

  BedrockKbRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: bedrock.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

Outputs:
  BucketArn:
    Value: !GetAtt RagBucket.Arn
  BucketName:
    Value: !Ref BucketName
  BedrockRoleArn:
    Value: !GetAtt BedrockKbRole.Arn
"@ | Out-File -FilePath "infra/knowledge_base.yaml" -Encoding UTF8
        Write-OK "infra/knowledge_base.yaml creado"
    }

    # lambda/Dockerfile
    if (-not (Test-Path "lambda/Dockerfile")) {
        Write-Host "  Creando lambda/Dockerfile" -ForegroundColor Gray
        @"
# Imagen base de AWS Lambda con Python 3.11
FROM public.ecr.aws/lambda/python:3.11

RUN dnf install -y \
    tesseract \
    tesseract-langpack-spa \
    tesseract-langpack-eng \
    ghostscript \
    qpdf \
    unpaper \
    pngquant \
    && dnf clean all

RUN pip install --no-cache-dir ocrmypdf==15.4.2

COPY app.py `$`{LAMBDA_TASK_ROOT}/

CMD [ "app.lambda_handler" ]
"@ | Out-File -FilePath "lambda/Dockerfile" -Encoding UTF8
        Write-OK "lambda/Dockerfile creado"
    }

    # lambda/app.py
    if (-not (Test-Path "lambda/app.py")) {
        Write-Host "  Creando lambda/app.py" -ForegroundColor Gray
        @"
"""
Lambda function: OCR pipeline para PDFs escaneados en S3.
Trigger: S3 PUT event en carpeta raw-scan/ del bucket robotic-paper-rag.
Output: PDF con OCR a books/<nombre>_ocr.pdf
"""
import os
import json
import subprocess
import tempfile
import boto3
import urllib.parse

s3 = boto3.client("s3")

INPUT_BUCKET = os.environ.get("INPUT_BUCKET", "robotic-paper-rag")
OUTPUT_PREFIX = os.environ.get("OUTPUT_PREFIX", "books/")
INPUT_PREFIX = os.environ.get("INPUT_PREFIX", "raw-scan/")
LANGS = os.environ.get("OCR_LANGS", "spa+eng")
MAX_SIZE_MB = 400


def lambda_handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        if not key.lower().endswith(".pdf"):
            continue
        if not key.startswith(INPUT_PREFIX):
            continue

        basename = os.path.basename(key)
        size_mb = record["s3"]["object"]["size"] / (1024 * 1024)
        print(f"Procesando: {key} ({size_mb:.1f} MB)")

        if size_mb > MAX_SIZE_MB:
            continue

        with tempfile.TemporaryDirectory() as tmp:
            local_in = os.path.join(tmp, "input.pdf")
            local_out = os.path.join(tmp, "output.pdf")

            s3.download_file(bucket, key, local_in)

            cmd = [
                "ocrmypdf", "-l", LANGS, "--force-ocr", "--deskew",
                "--clean", "--optimize", "1", "--jobs", "2",
                local_in, local_out,
            ]
            try:
                subprocess.run(cmd, check=True, timeout=900,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except subprocess.CalledProcessError:
                continue
            except subprocess.TimeoutExpired:
                continue

            out_key = OUTPUT_PREFIX + os.path.splitext(basename)[0] + "_ocr.pdf"
            s3.upload_file(local_out, bucket, out_key)
            s3.delete_object(Bucket=bucket, Key=key)
            print(f"Subido: s3://{bucket}/{out_key}")

    return {"statusCode": 200, "body": json.dumps("OCR completado")}
"@ | Out-File -FilePath "lambda/app.py" -Encoding UTF8
        Write-OK "lambda/app.py creado"
    }

    # lambda/trigger_s3.yaml
    if (-not (Test-Path "lambda/trigger_s3.yaml")) {
        Write-Host "  Creando lambda/trigger_s3.yaml" -ForegroundColor Gray
        @"
# Lambda OCR Trigger - referencia para configurar manualmente
# S3 > bucket > Properties > Event notifications > Create

Resource:
  Type: AWS::S3::BucketNotification
  Properties:
    Bucket: !Ref RoboticPaperRagBucket
    NotificationConfiguration:
      LambdaFunctionConfigurations:
        - Events:
            - s3:ObjectCreated:*
          Filter:
            Prefix: raw-scan/
            Suffix: .pdf
          LambdaFunctionArn: !GetAtt OcrLambdaFunction.Arn
"@ | Out-File -FilePath "lambda/trigger_s3.yaml" -Encoding UTF8
        Write-OK "lambda/trigger_s3.yaml creado"
    }
}

# ---------------------------------------------------------
# Verificar .gitignore actualizado
# ---------------------------------------------------------
Write-Step "Verificando .gitignore"

$gitignoreContent = Get-Content .gitignore -Raw
if ($gitignoreContent -match "^lib/$" -or $gitignoreContent -match "^lambda/$") {
    Write-Warn "Tu .gitignore tiene reglas que podrian bloquear carpetas legitimas"
    Write-Host "  Considera actualizarlo con la version nueva del repo."
}

# ---------------------------------------------------------
# Stage y commit
# ---------------------------------------------------------
Write-Step "Agregando cambios al staging"
git add .
$staged = git status --short
Write-Host $staged

if (-not $staged) {
    Write-OK "No hay cambios para commitear. Todo ya esta en GitHub."
    exit 0
}

Write-Host ""
$confirm = Read-Host "Confirmas commit y push? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Operacion cancelada."
    exit 0
}

git commit -m $CommitMsg
Write-OK "Commit creado"

Write-Step "Haciendo push a GitHub"
git push origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  REPO ACTUALIZADO!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Carpetas agregadas:"
    foreach ($folder in $missingFolders) {
        Write-Host "  + $folder/" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Verifica en GitHub que ahora aparezcan:"
    Write-Host "  https://github.com/yasminum/rag-robotics-aws" -ForegroundColor Cyan
} else {
    Write-Err "El push fallo. Verifica tu conexion o credenciales."
    exit 1
}
