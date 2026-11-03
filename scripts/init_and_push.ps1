# =====================================================================
# init_and_push.ps1
# Inicializa el repo y hace el primer push a GitHub
# Versión NATIVA de Windows PowerShell (sin WSL)
# =====================================================================
# USO:
#   1. Crea el repo en GitHub SIN README, SIN .gitignore, SIN LICENSE
#      https://github.com/new
#      Nombre: rag-robotics-aws
#
#   2. Abre PowerShell en la carpeta del repo (click derecho → "Abrir
#      terminal aquí" o en Antigravity: Ctrl+`)
#
#   3. Ejecuta:
#        powershell -ExecutionPolicy Bypass -File .\scripts\init_and_push.ps1 -GithubUser "yurrego"
# =====================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$GithubUser,

    [string]$RepoName = "rag-robotics-aws"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[X] $msg" -ForegroundColor Red }

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "  Inicializando repo: $RepoName" -ForegroundColor Yellow
Write-Host "  GitHub user: $GithubUser" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow

# ---------------------------------------------------------
# 1. Verificar que git esté instalado
# ---------------------------------------------------------
Write-Step "Verificando dependencias"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "Git no está instalado."
    Write-Host "  Descarga de: https://git-scm.com/download/win"
    Write-Host "  Durante la instalacion selecciona: 'Use Git from the Windows Command Prompt'"
    exit 1
}
$gitVersion = (git --version) 2>&1
Write-OK "Git detectado: $gitVersion"

# ---------------------------------------------------------
# 2. Verificar que NO haya credenciales hardcodeadas
# ---------------------------------------------------------
Write-Step "Verificando que no haya credenciales en el codigo"

$secretPatterns = @(
    "AKIA[0-9A-Z]{16}",
    "aws_secret_access_key\s*=",
    "-----BEGIN.*PRIVATE KEY-----"
)

$foundSecrets = $false
foreach ($pattern in $secretPatterns) {
    $files = Get-ChildItem -Path . -Recurse -File |
        Where-Object { $_.FullName -notmatch "\\.git\\" -and $_.FullName -notmatch "node_modules" }
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and ($content -match $pattern)) {
            Write-Err "Patron sospechoso en $($file.FullName): $pattern"
            $foundSecrets = $true
        }
    }
}
if ($foundSecrets) { exit 1 }
Write-OK "No se encontraron credenciales comprometidas"

# ---------------------------------------------------------
# 3. Verificar que .gitignore existe
# ---------------------------------------------------------
if (-not (Test-Path .gitignore)) {
    Write-Err "Falta el archivo .gitignore"
    exit 1
}
Write-OK ".gitignore presente"

# ---------------------------------------------------------
# 4. Verificar que NO haya PDFs en el repo
# ---------------------------------------------------------
$pdfFiles = Get-ChildItem -Path . -Recurse -Include *.pdf, *.PDF |
    Where-Object { $_.FullName -notmatch "\\.git\\" -and $_.FullName -notmatch "\\docs\\" }
if ($pdfFiles) {
    Write-Err "Se encontraron $($pdfFiles.Count) archivos PDF en el repo:"
    $pdfFiles | ForEach-Object { Write-Host "  - $($_.FullName)" -ForegroundColor Red }
    Write-Host "  Los PDFs NO deben subirse por copyright."
    exit 1
}
Write-OK "No hay PDFs comprometedores"

# ---------------------------------------------------------
# 5. Inicializar git
# ---------------------------------------------------------
Write-Step "Inicializando git"
if (-not (Test-Path .git)) {
    git init
    git branch -M main
    Write-OK "Git inicializado (rama main)"
} else {
    Write-Warn "Git ya estaba inicializado"
}

# ---------------------------------------------------------
# 6. Stage y commit
# ---------------------------------------------------------
Write-Step "Agregando archivos al staging"
git add .
$staged = git status --short
if (-not $staged) {
    Write-Warn "No hay archivos para commitear. Ya esta todo subido?"
    exit 0
}
Write-Host $staged

$confirm = Read-Host "`nConfirmas el commit? (y/N)"
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "Commit cancelado."
    exit 0
}

git commit -m @"
Initial commit: RAG Robotics AWS Knowledge Base

- Pipeline de ingesta: scraper arXiv + OCR + upload S3
- Lambda alternativa serverless para OCR automatico
- CloudFormation: S3 + Bedrock KB + OpenSearch + IAM
- Documentacion completa: README + guia paso a paso
- CI: GitHub Actions valida sintaxis y detecta secretos
"@

Write-OK "Commit creado"

# ---------------------------------------------------------
# 7. Configurar remote y push
# ---------------------------------------------------------
Write-Step "Configurando remote"
$remoteUrl = "https://github.com/$GithubUser/$RepoName.git"

$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    git remote set-url origin $remoteUrl
    Write-OK "Remote actualizado"
} else {
    git remote add origin $remoteUrl
    Write-OK "Remote agregado"
}
Write-Host "  URL: $remoteUrl"

# ---------------------------------------------------------
# 8. Push
# ---------------------------------------------------------
Write-Step "Haciendo push a GitHub"
Write-Host "Si te pide credenciales:" -ForegroundColor Yellow
Write-Host "  Usuario: tu usuario de GitHub" -ForegroundColor Yellow
Write-Host "  Password: tu Personal Access Token (PAT), NO tu contrasena" -ForegroundColor Yellow
Write-Host "  Genera PAT en: https://github.com/settings/tokens" -ForegroundColor Yellow
Write-Host "  Scope: 'repo' (full control of private repositories)" -ForegroundColor Yellow
Write-Host ""

git push -u origin main
if ($LASTEXITCODE -ne 0) {
    Write-Err "El push fallo. Verifica tus credenciales."
    Write-Host "  Si usas PAT y sigue fallando, ejecuta:"
    Write-Host "    git config --global credential.helper manager"
    Write-Host "    git push -u origin main"
    exit 1
}

# ---------------------------------------------------------
# Resumen final
# ---------------------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  REPO SUBIDO A GITHUB!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "  URL: https://github.com/$GithubUser/$RepoName" -ForegroundColor White
Write-Host ""
Write-Host "Proximos pasos recomendados:" -ForegroundColor Cyan
Write-Host "  1. Edita LICENSE y reemplaza [Tu Nombre]"
Write-Host "  2. Agrega topics: robotics, aws, bedrock, rag, ml"
Write-Host "  3. Pinealo en tu perfil de GitHub"
Write-Host "================================================"
