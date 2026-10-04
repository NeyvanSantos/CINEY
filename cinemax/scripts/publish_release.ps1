param (
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$Notes = "Atualizacao automatica com melhorias de estabilidade e novas fontes.",

    [switch]$BuildLocal
)

$ErrorActionPreference = "Stop"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  CineMax - Publicador de Release Automatica" -ForegroundColor Cyan
Write-Host "  Versao Alvo: v$Version" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$rootDir = Split-Path -Parent $projectDir
$pubspecPath = Join-Path $projectDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "Arquivo pubspec.yaml nao encontrado em: $pubspecPath"
    exit 1
}

# 1. Atualizar versao no pubspec.yaml
Write-Host "`nAtualizando versao em pubspec.yaml..." -ForegroundColor Cyan
$content = Get-Content $pubspecPath -Raw

if ($content -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $currentBuild = [int]$matches[2]
    $newBuild = $currentBuild + 1
} else {
    $newBuild = 1
}

$newVersionLine = "version: $Version+$newBuild"
$content = $content -replace "version:\s*.*", $newVersionLine
Set-Content -Path $pubspecPath -Value $content -NoNewline
Write-Host "Versao definida: $newVersionLine" -ForegroundColor Green

# 2. Compilacao Local Opcional
if ($BuildLocal) {
    Write-Host "`nCompilando APK Release localmente..." -ForegroundColor Cyan
    Push-Location $projectDir
    try {
        flutter build apk --release
        Write-Host "APK compilado com sucesso localmente!" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

# 3. Git Commit e Tag
Push-Location $rootDir
try {
    Write-Host "`nVersionando no Git..." -ForegroundColor Cyan
    git add cinemax/pubspec.yaml

    $tag = "v$Version"
    $commitMsg = "chore(release): bump version to $tag [skip ci]"

    $status = git status --porcelain cinemax/pubspec.yaml
    if ($status) {
        git commit -m $commitMsg
    }

    $existingTag = git tag -l $tag
    if ($existingTag) {
        Write-Host "Tag $tag ja existe. Atualizando tag..." -ForegroundColor Yellow
        git tag -d $tag
    }

    git tag -a $tag -m "Release $tag - $Notes"
    Write-Host "Tag $tag criada com sucesso!" -ForegroundColor Green

    # 4. Enviar para o GitHub
    Write-Host "`nEnviando alteracoes e Tag para o GitHub..." -ForegroundColor Cyan
    git push origin main
    git push origin $tag --force

    Write-Host "`nSUCESSO! A Tag $tag foi enviada para o GitHub!" -ForegroundColor Green
    Write-Host "O GitHub Actions foi acionado automaticamente na nuvem." -ForegroundColor Cyan
    Write-Host "Acompanhe em: https://github.com/NeyvanSantos/CINEY/actions" -ForegroundColor Yellow
    Write-Host "A Release sera publicada em: https://github.com/NeyvanSantos/CINEY/releases" -ForegroundColor Yellow
} finally {
    Pop-Location
}
