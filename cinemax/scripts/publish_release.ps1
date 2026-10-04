<#
.SYNOPSIS
    Script de Automação de Releases do CineMax no GitHub.
.DESCRIPTION
    Atualiza a versão no pubspec.yaml, gera a tag Git, envia para o GitHub e dispara
    automaticamente a compilação do APK e publicação da Release via GitHub Actions.
.PARAMETER Version
    Nova versão sem prefixo 'v' (Exemplo: 1.0.1).
.PARAMETER Notes
    Descrição ou notas da release para os usuários.
.PARAMETER BuildLocal
    Se definido, compila o APK localmente antes de subir.
.EXAMPLE
    .\publish_release.ps1 -Version "1.0.1" -Notes "Correção de players e novas fontes"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$Notes = "Atualização automática com melhorias de estabilidade e novas fontes.",

    [switch]$BuildLocal
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " 🚀 CineMax - Publicador de Release Automática" -ForegroundColor Cyan
Write-Host " Versão Alvo: v$Version" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

# 1. Caminhos
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir
$rootDir = Split-Path -Parent $projectDir
$pubspecPath = Join-Path $projectDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    Write-Error "Arquivo pubspec.yaml não encontrado em: $pubspecPath"
    exit 1
}

# 2. Atualizar versão no pubspec.yaml
Write-Host "`n📝 Atualizando versão em pubspec.yaml..." -ForegroundColor Cyan
$content = Get-Content $pubspecPath -Raw

# Extrai o build number atual e incrementa
if ($content -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $currentBuild = [int]$matches[2]
    $newBuild = $currentBuild + 1
} else {
    $newBuild = 1
}

$newVersionLine = "version: $Version+$newBuild"
$content = $content -replace "version:\s*.*", $newVersionLine
Set-Content -Path $pubspecPath -Value $content -NoNewline
Write-Host "✅ Versão definida: $newVersionLine" -ForegroundColor Green

# 3. Compilação Local Opcional
if ($BuildLocal) {
    Write-Host "`n🔨 Compilando APK Release localmente..." -ForegroundColor Cyan
    Push-Location $projectDir
    try {
        flutter build apk --release
        Write-Host "✅ APK compilado com sucesso localmente!" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

# 4. Git Commit & Tag
Push-Location $rootDir
try {
    Write-Host "`n📦 Versionando no Git..." -ForegroundColor Cyan
    git add cinemax/pubspec.yaml

    $tag = "v$Version"
    $commitMsg = "chore(release): bump version to $tag [skip ci]"

    # Verifica se há alterações para commitar
    $status = git status --porcelain cinemax/pubspec.yaml
    if ($status) {
        git commit -m $commitMsg
    }

    # Verifica se a tag já existe localmente
    $existingTag = git tag -l $tag
    if ($existingTag) {
        Write-Host "⚠️ Tag $tag já existe. Atualizando tag..." -ForegroundColor Yellow
        git tag -d $tag
    }

    git tag -a $tag -m "Release $tag: $Notes"
    Write-Host "✅ Tag $tag criada com sucesso!" -ForegroundColor Green

    # 5. Enviar para o GitHub
    Write-Host "`n🌐 Enviando alterações e Tag para o GitHub..." -ForegroundColor Cyan
    git push origin main
    git push origin $tag --force

    Write-Host "`n🎉 SUCESSO! A Tag $tag foi enviada para o GitHub!" -ForegroundColor Green
    Write-Host "⚡ O GitHub Actions foi acionado automaticamente na nuvem." -ForegroundColor Cyan
    Write-Host "🔗 Acompanhe em: https://github.com/NeyvanSantos/CINEY/actions" -ForegroundColor Yellow
    Write-Host "📦 A Release será publicada em: https://github.com/NeyvanSantos/CINEY/releases" -ForegroundColor Yellow
} finally {
    Pop-Location
}
