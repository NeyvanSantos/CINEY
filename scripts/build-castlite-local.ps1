param([ValidatePattern('^[A-Za-z]:$')][string]$BuildDrive = 'X:')

$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$buildRoot = "$BuildDrive\"
$createdMapping = $false
$locationChanged = $false

try {
    # CMake/JNI no Windows não gera corretamente os arquivos no caminho com acentos.
    if (Test-Path -LiteralPath $buildRoot) {
        throw "A unidade $BuildDrive já está em uso. Escolha outra com -BuildDrive."
    }
    & subst $BuildDrive $workspace
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível criar o caminho curto de build.' }
    $createdMapping = $true
    Push-Location -LiteralPath "$BuildDrive\cinemax"
    $locationChanged = $true
    & flutter build apk --debug --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'Falha na compilação local do CiNey integrado.' }
    Write-Output "APK local: $workspace\cinemax\build\app\outputs\flutter-apk\app-debug.apk"
} finally {
    if ($locationChanged) { Pop-Location }
    # Remove somente o alias criado neste processo; os arquivos permanecem no checkout.
    if ($createdMapping) { & subst $BuildDrive /D }
}
