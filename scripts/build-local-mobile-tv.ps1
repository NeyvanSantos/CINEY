param(
    [ValidateSet('mobile', 'tv', 'both')][string]$Target = 'both',
    [ValidatePattern('^[A-Za-z]:$')][string]$BuildDrive = 'X:',
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
$workspacePath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scratchPath = Join-Path $workspacePath '.work\dependency-separation'
$outputPath = Join-Path $workspacePath 'outputs'
$utf8 = New-Object Text.UTF8Encoding($false)
$mappedDrive = $false
$pushedLocation = $false
$configuredHosts = @()
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'

New-Item -ItemType Directory -Path $scratchPath, $outputPath -Force | Out-Null
try {
    if (Test-Path -LiteralPath "$BuildDrive\") { throw "A unidade $BuildDrive ja esta em uso." }
    & subst $BuildDrive $workspacePath
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar caminho ASCII para o build.' }
    $mappedDrive = $true
    $buildTargets = if ($Target -eq 'both') { @('mobile', 'tv') } else { @($Target) }
    foreach ($buildTarget in $buildTargets) {
        $hostFolder = if ($buildTarget -eq 'tv') { 'cinemax_tv' } else { 'cinemax' }
        $configuredHosts += $hostFolder
        $pubspecText = Get-Content -LiteralPath (Join-Path $workspacePath "$hostFolder\pubspec.yaml") -Raw
        $versionMatch = [regex]::Match($pubspecText, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
        if (-not $versionMatch.Success) { throw "Versao invalida em $hostFolder/pubspec.yaml" }
        $versionName = $versionMatch.Groups[1].Value
        $versionCode = [int]$versionMatch.Groups[2].Value
        $buildType = if ($buildTarget -eq 'tv') { 'release' } else { 'debug' }
        $suffix = if ($buildTarget -eq 'tv') { '.lite_test' } else { '.castlite_test' }
        $label = if ($buildTarget -eq 'tv') { 'CiNey TV Teste' } else { 'CiNey Teste' }
        $initName = "local-$buildTarget.gradle"
        $manifestName = "local-$buildTarget-manifest.xml"
        $manifestPath = "$BuildDrive/.work/dependency-separation/$manifestName"
        $initText = @"
gradle.beforeProject { project ->
    project.pluginManager.withPlugin('com.android.application') {
        def android = project.extensions.getByName('android')
        android.buildTypes.getByName('$buildType').applicationIdSuffix = '$suffix'
        android.buildTypes.getByName('$buildType').versionNameSuffix = '-teste-local'
        android.sourceSets.getByName('$buildType').manifest.srcFile('$manifestPath')
        project.extensions.getByName('androidComponents').finalizeDsl { dsl ->
            dsl.defaultConfig.versionName = '$versionName'
            dsl.defaultConfig.versionCode = $versionCode
            def localSigning = dsl.signingConfigs.maybeCreate('cineyLocalTest')
            localSigning.storeFile = new File(System.getProperty('user.home'), '.android/debug.keystore')
            localSigning.storePassword = 'android'
            localSigning.keyAlias = 'androiddebugkey'
            localSigning.keyPassword = 'android'
            dsl.buildTypes.getByName('$buildType').signingConfig = localSigning
        }
    }
}
"@
        $manifestText = @"
<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:label="$label" tools:replace="android:label" />
</manifest>
"@
        [IO.File]::WriteAllText((Join-Path $scratchPath $initName), $initText, $utf8)
        [IO.File]::WriteAllText((Join-Path $scratchPath $manifestName), $manifestText, $utf8)
        Push-Location -LiteralPath "$BuildDrive\$hostFolder"
        $pushedLocation = $true
        $pubArgs = @('pub', 'get')
        if ($Offline) { $pubArgs += '--offline' }
        & flutter @pubArgs *> (Join-Path $scratchPath "pub-$buildTarget.log")
        if ($LASTEXITCODE -ne 0) { throw "Falha no pub get de $buildTarget." }
        Pop-Location
        $pushedLocation = $false
        Push-Location -LiteralPath "$BuildDrive\$hostFolder\android"
        $pushedLocation = $true
        $gradleArgs = @(
            '--no-daemon', '--max-workers=2', '--console=plain',
            '-Dorg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=2G -XX:ReservedCodeCacheSize=512m',
            '-I', "$BuildDrive\.work\dependency-separation\$initName",
            '-Ptarget-platform=android-arm,android-arm64,android-x64',
            '-Ptarget=lib/main.dart', '-Pbase-application-name=android.app.Application',
            '-Pdart-obfuscation=false'
        )
        if ($Offline) { $gradleArgs += '--offline' }
        if ($buildTarget -eq 'tv') {
            $gradleArgs += @('-Psplit-per-abi=true', '-Ptree-shake-icons=true', ':app:assembleRelease')
        } else {
            $gradleArgs += @('-Ptrack-widget-creation=true', '-Ptree-shake-icons=false', ':app:assembleDebug')
        }
        $buildLog = Join-Path $scratchPath "build-$buildTarget.log"
        & .\gradlew.bat @gradleArgs *> $buildLog
        $gradleExit = $LASTEXITCODE
        Get-Content -LiteralPath $buildLog -Tail 24
        if ($gradleExit -ne 0) { throw "Falha no build de $buildTarget. Consulte $buildLog" }
        $apkFolder = "$BuildDrive\$hostFolder\build\app\outputs\apk\$buildType"
        $metadata = Get-Content -LiteralPath (Join-Path $apkFolder 'output-metadata.json') -Raw | ConvertFrom-Json
        $expectedId = if ($buildTarget -eq 'tv') { 'com.ciney.tv.lite_test' } else { 'com.ciney.app.castlite_test' }
        if ($metadata.applicationId -ne $expectedId) { throw 'O APK nao possui o pacote privado esperado.' }
        foreach ($element in $metadata.elements) {
            if ($element.versionName -ne "$versionName-teste-local") { throw 'Versao do APK diferente do pubspec.' }
            $apkName = if ($buildTarget -eq 'mobile') { 'CiNey-CastLite-BlueStacks-teste.apk' } else {
                $abi = ($element.filters | Where-Object filterType -eq 'ABI').value
                if (-not $abi) { throw 'APK TV sem identificacao de arquitetura.' }
                "CiNey-TV-Leve-teste-$abi.apk"
            }
            Copy-Item -LiteralPath (Join-Path $apkFolder $element.outputFile) -Destination (Join-Path $outputPath $apkName) -Force
            Write-Output "APK local: $apkName"
        }
        Pop-Location
        $pushedLocation = $false
    }
} finally {
    if ($pushedLocation) { Pop-Location }
    if ($mappedDrive) { & subst $BuildDrive /D }
    # Restaura metadados de plugins com o caminho real para uso posterior na IDE.
    foreach ($hostFolder in $configuredHosts) {
        Push-Location -LiteralPath (Join-Path $workspacePath $hostFolder)
        try {
            & flutter pub get --offline *> (Join-Path $scratchPath "restore-$hostFolder.log")
            if ($LASTEXITCODE -ne 0) { Write-Warning "Reexecute flutter pub get em $hostFolder." }
        } finally { Pop-Location }
    }
}
