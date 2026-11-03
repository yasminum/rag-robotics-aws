# =====================================================================
# fix_repo.ps1 - Arregla TODO de una vez
# =====================================================================
# Ejecuta este script UNA sola vez para:
#   1. Crear las carpetas que faltan (docs/, infra/, lambda/)
#   2. Actualizar el .gitignore y README.md
#   3. Actualizar el workflow CI que estaba fallando
#   4. Hacer commit + push a GitHub
# =====================================================================
# USO:
#   cd "C:\Users\yurrego\OneDrive - EFICITEC S.A.C\Documentos\rag-robotics-aws"
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\scripts\fix_repo.ps1
# =====================================================================

param(
    [string]$CommitMsg = "Fix: add missing folders, fix CI workflow, update README"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  FIX REPO - rag-robotics-aws" -ForegroundColor Yellow
Write-Host "  Arregla carpetas + CI + gitignore + push" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# ---------------------------------------------------------
# Verificar que estamos en la raiz del repo
# ---------------------------------------------------------
if (-not (Test-Path .git)) {
    Write-Err "No estas en la raiz del repo."
    Write-Host "  Ejecuta este script desde la carpeta rag-robotics-aws/"
    exit 1
}

# ---------------------------------------------------------
# 1. Crear carpetas faltantes con archivos completos
# ---------------------------------------------------------
Write-Step "1/5 - Verificando y creando carpetas"

# docs/INSTRUCCIONES_AWS_OCR.md
if (-not (Test-Path "docs")) { New-Item -ItemType Directory -Path "docs" -Force | Out-Null }
if (-not (Test-Path "docs/INSTRUCCIONES_AWS_OCR.md")) {
    Write-Host "  Creando docs/INSTRUCCIONES_AWS_OCR.md" -ForegroundColor Gray
    @"
# OCR gratis en AWS + RAG con Bedrock - Guia completa

## Arquitectura

``````
[Tu PC]
   | aws s3 cp libro_escaneado.pdf s3://robotic-paper-rag/raw-scan/
   v
[S3: robotic-paper-rag/raw-scan/]   <- PDFs escaneados entran aqui
   |
   v (pipeline OCR)
[S3: robotic-paper-rag/books/]      <- PDFs con texto salen aqui
   |
   v (Bedrock Knowledge Base Sync)
[OpenSearch Serverless o S3 Vectors] <- vectores indexados
   |
   v
[Bedrock LLM (Claude/Titan)]        <- consultas del usuario
``````

## Opcion A: OCR Local en Windows (recomendada para pocos libros)

```powershell
# 1. Setup (instala Tesseract + OCRmyPDF)
.\scripts\02_setup_ocr_windows.ps1

# 2. Procesa y sube tus PDFs
.\scripts\03_pipeline_ocr_windows.ps1 -SourcePath "C:\ruta\escaneados"
```

## Opcion B: OCR en EC2 Free Tier

1. Lanza EC2 Amazon Linux 2023, t3.micro, 30GB disco
2. Asigna IAM role con permisos S3ReadWrite sobre tu bucket
3. Conecta por SSH y ejecuta:
   ````bash
   bash scripts/02_setup_ec2_ocr.sh
   bash scripts/03_pipeline_ocr.sh
   ````

## Costos

| Servicio | Free Tier | Costo pago |
|---|---|---|
| EC2 t3.micro | 750h/mes x 12 meses | `$0` |
| S3 5GB | 12 meses | `$0.023/GB-mes` |
| Bedrock Titan Embeddings | NO | `$0.0001/1K tokens` |
| Bedrock Claude 3.5 | NO | `$3-15 / 1M tokens` |
| OpenSearch Serverless | NO | `$50-100/mes min` |
| S3 Vectors (nuevo 2025) | NO | `$0.001/1K vectores` |

## Troubleshooting

### OCR falla en PDFs grandes
- t3.micro tiene 1 vCPU, PDFs > 300 paginas tardan 30+ min
- Cambia a t3.small o divide con `qpdf --split-pages`

### Bedrock no encuentra PDFs
- Verifica que esten en `books/`, `papers/` o `classroom/`, NO en `raw-scan/`
- El S3 URI en KB debe ser `s3://robotic-paper-rag/` (raiz)

### Error "Model access pending"
- Bedrock > Model access > solicita acceso a Titan Embeddings V2
- En cuentas nuevas puede tardar hasta 24h
"@ | Out-File -FilePath "docs/INSTRUCCIONES_AWS_OCR.md" -Encoding UTF8
    Write-OK "docs/INSTRUCCIONES_AWS_OCR.md"
}

# infra/README.md
if (-not (Test-Path "infra")) { New-Item -ItemType Directory -Path "infra" -Force | Out-Null }
if (-not (Test-Path "infra/README.md")) {
    Write-Host "  Creando infra/README.md" -ForegroundColor Gray
    @"
# Infraestructura como codigo (IaC)

## Archivos

- ````knowledge_base.yaml```` - CloudFormation template que crea:
  - Bucket S3 ````robotic-paper-rag````
  - IAM role para Bedrock
  - Knowledge Base con Titan Embeddings V2
  - OpenSearch Serverless collection

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
    Write-OK "infra/README.md"
}

# infra/knowledge_base.yaml
if (-not (Test-Path "infra/knowledge_base.yaml")) {
    Write-Host "  Creando infra/knowledge_base.yaml" -ForegroundColor Gray
    @"
AWSTemplateFormatVersion: '2010-09-09'
Description: 'RAG Robotics AWS - Knowledge Base'

Parameters:
  BucketName:
    Type: String
    Default: robotic-paper-rag
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
      Policies:
        - PolicyName: BedrockKbS3Access
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - s3:GetObject
                  - s3:ListBucket
                Resource:
                  - !Sub 'arn:aws:s3:::`${BucketName}`'
                  - !Sub 'arn:aws:s3:::`${BucketName}/*`'

  OpenSearchCollection:
    Type: AWS::OpenSearchServerless::Collection
    Properties:
      Name: rag-robotics-vectors
      Type: VECTORSEARCH
      Description: 'Vector store for RAG Knowledge Base'

Outputs:
  BucketArn:
    Value: !GetAtt RagBucket.Arn
  BucketName:
    Value: !Ref BucketName
  BedrockRoleArn:
    Value: !GetAtt BedrockKbRole.Arn
  OpenSearchCollectionArn:
    Value: !GetAtt OpenSearchCollection.Arn
"@ | Out-File -FilePath "infra/knowledge_base.yaml" -Encoding UTF8
    Write-OK "infra/knowledge_base.yaml"
}

# lambda/Dockerfile
if (-not (Test-Path "lambda")) { New-Item -ItemType Directory -Path "lambda" -Force | Out-Null }
if (-not (Test-Path "lambda/Dockerfile")) {
    Write-Host "  Creando lambda/Dockerfile" -ForegroundColor Gray
    @"
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

COPY app.py `${LAMBDA_TASK_ROOT}/

CMD [ "app.lambda_handler" ]
"@ | Out-File -FilePath "lambda/Dockerfile" -Encoding UTF8
    Write-OK "lambda/Dockerfile"
}

# lambda/app.py
if (-not (Test-Path "lambda/app.py")) {
    Write-Host "  Creando lambda/app.py" -ForegroundColor Gray
    @"
"""Lambda: OCR pipeline para PDFs escaneados en S3."""
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
        if not key.lower().endswith(".pdf") or not key.startswith(INPUT_PREFIX):
            continue
        basename = os.path.basename(key)
        size_mb = record["s3"]["object"]["size"] / (1024 * 1024)
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
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                continue
            out_key = OUTPUT_PREFIX + os.path.splitext(basename)[0] + "_ocr.pdf"
            s3.upload_file(local_out, bucket, out_key)
            s3.delete_object(Bucket=bucket, Key=key)
    return {"statusCode": 200, "body": json.dumps("OCR completado")}
"@ | Out-File -FilePath "lambda/app.py" -Encoding UTF8
    Write-OK "lambda/app.py"
}

# lambda/trigger_s3.yaml
if (-not (Test-Path "lambda/trigger_s3.yaml")) {
    Write-Host "  Creando lambda/trigger_s3.yaml" -ForegroundColor Gray
    @"
# S3 trigger para Lambda OCR
# Configurar manualmente en: S3 > bucket > Properties > Event notifications
Resource:
  Type: AWS::S3::BucketNotification
  Properties:
    Bucket: !Ref RoboticPaperRagBucket
    NotificationConfiguration:
      LambdaFunctionConfigurations:
        - Events: [s3:ObjectCreated:*]
          Filter:
            Prefix: raw-scan/
            Suffix: .pdf
          LambdaFunctionArn: !GetAtt OcrLambdaFunction.Arn
"@ | Out-File -FilePath "lambda/trigger_s3.yaml" -Encoding UTF8
    Write-OK "lambda/trigger_s3.yaml"
}

# ---------------------------------------------------------
# 2. Verificar .gitignore
# ---------------------------------------------------------
Write-Step "2/5 - Verificando .gitignore"

$gitignoreContent = Get-Content .gitignore -Raw -ErrorAction SilentlyContinue
if (-not $gitignoreContent) {
    Write-Warn ".gitignore no encontrado o vacio"
} else {
    # Verificar que no tenga reglas problematicas
    $problematicas = @("^lib/$", "^lambda/$", "^infra/$", "^docs/$")
    $hasProblem = $false
    foreach ($pattern in $problematicas) {
        if ($gitignoreContent -match $pattern) {
            Write-Warn ".gitignore tiene regla problematica: $pattern"
            $hasProblem = $true
        }
    }
    if (-not $hasProblem) {
        Write-OK ".gitignore no tiene reglas problematicas"
    }
}

# ---------------------------------------------------------
# 3. Listar cambios
# ---------------------------------------------------------
Write-Step "3/5 - Estado del repo"
git status --short

# ---------------------------------------------------------
# 4. Commit y push
# ---------------------------------------------------------
Write-Step "4/5 - Commit y push"

Write-Host "Mensaje de commit: $CommitMsg" -ForegroundColor Gray
$confirm = Read-Host "Confirmas commit y push? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Operacion cancelada."
    exit 0
}

git add .
git commit -m $CommitMsg

if ($LASTEXITCODE -ne 0) {
    Write-Err "El commit fallo"
    exit 1
}
Write-OK "Commit creado"

Write-Step "5/5 - Push a GitHub"
git push origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "  REPO ARREGLADO Y SUBIDO!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Carpetas que ahora deberias ver en GitHub:" -ForegroundColor White
    Write-Host "  .github/workflows/" -ForegroundColor Green
    Write-Host "  diagrams/" -ForegroundColor Green
    Write-Host "  docs/          [NUEVA]" -ForegroundColor Yellow
    Write-Host "  infra/          [NUEVA]" -ForegroundColor Yellow
    Write-Host "  lambda/         [NUEVA]" -ForegroundColor Yellow
    Write-Host "  scripts/" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verifica en:" -ForegroundColor White
    Write-Host "  https://github.com/yasminum/rag-robotics-aws" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "El CI deberia pasar en ~30 segundos."
    Write-Host "Si sigue fallando, mira los detalles en la pestana 'Actions'."
} else {
    Write-Err "El push fallo. Posibles causas:"
    Write-Host "  - No tienes permisos sobre el repo"
    Write-Host "  - Tu Personal Access Token expiro"
    Write-Host "  - No estas autenticado"
    Write-Host ""
    Write-Host "Solucion: ejecuta 'git push origin main' manualmente"
    Write-Host "y mira el error especifico."
}
