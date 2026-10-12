    param (
        [string]$Version,
        [string]$Notes,
        [switch]$PreflightOnly
    )

    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    $repoSlug = 'NeyvanSantos/CINEY'
    $workflowFile = 'release.yml'
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $rootDir = Split-Path -Parent $scriptDir
    $projectDir = Join-Path $rootDir 'cinemax'
    $pubspecPath = Join-Path $projectDir 'pubspec.yaml'
    $inventoryPath = Join-Path $rootDir 'releases/README.md'
    $releaseDirectory = Join-Path $rootDir 'releases/mobile'

    function Invoke-Checked {
        param (
            [string]$Executable,
            [string[]]$Arguments,
            [string]$Description
        )

        & $Executable @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Description (exit code $LASTEXITCODE)."
        }
    }

    function Get-CommandText {
        param (
            [string]$Executable,
            [string[]]$Arguments,
            [string]$Description
        )

        $output = & $Executable @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "$Description (exit code $LASTEXITCODE)."
        }
        return (($output | ForEach-Object { "$_" }) -join "`n").Trim()
    }

    function Get-RemoteTagLines {
        param ([string]$Tag)

        $ref = "refs/tags/$Tag"
        $output = & git ls-remote --tags origin $ref "$ref^{}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw 'Nao foi possivel consultar as tags no GitHub.'
        }
        return @($output | ForEach-Object { "$_" } | Where-Object { $_ })
    }

    function Get-ReleaseInfo {
        param ([string]$Tag)

        $output = & gh release view $Tag --repo $repoSlug --json tagName,assets 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $output) {
            return $null
        }
        return (($output -join "`n") | ConvertFrom-Json)
    }

    function Get-NextVersion {
        param ([string]$CurrentVersion)

        $parts = $CurrentVersion.Split('.')
        return '{0}.{1}.{2}' -f [int]$parts[0], [int]$parts[1], ([int]$parts[2] + 1)
    }

    Push-Location -LiteralPath $rootDir
    try {
        if (-not (Test-Path $pubspecPath)) {
            throw "Arquivo pubspec.yaml nao encontrado: $pubspecPath"
        }

        foreach ($tool in @('git', 'gh', 'flutter', 'node')) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                throw "Ferramenta obrigatoria nao encontrada no PATH: $tool"
            }
        }

        Invoke-Checked 'gh' @('auth', 'status', '--hostname', 'github.com') 'Autenticacao do GitHub indisponivel'

        $branch = Get-CommandText 'git' @('branch', '--show-current') 'Falha ao ler a branch atual'
        if ($branch -cne 'main') {
            throw 'Publique somente a partir da branch main; o preflight tambem exige main.'
        }
        $remoteUrl = Get-CommandText 'git' @('remote', 'get-url', 'origin') 'Remote origin indisponivel'
        if ($remoteUrl -notmatch '(?i)github\.com[:/]NeyvanSantos/CINEY(?:\.git)?$') {
            throw "O remote origin nao aponta para github.com/$repoSlug. Nenhuma alteracao foi feita."
        }
        Invoke-Checked 'git' @('fetch', 'origin') 'Falha ao atualizar origin antes de validar main'
        $behindCount = [int](Get-CommandText 'git' @('rev-list', '--count', 'main..origin/main') 'Falha ao comparar main com origin/main')
        if ($behindCount -gt 0) {
            throw "A main local esta atras de origin/main em $behindCount commit(s), ou divergiu. Atualize main antes de publicar; nenhum push foi feito."
        }
        $localCommits = Get-CommandText 'git' @('log', '--oneline', 'origin/main..main') 'Falha ao listar commits locais'
        if ($localCommits) {
            Write-Host 'Commits locais da main ainda nao enviados; serao incluidos na publicacao:' -ForegroundColor Yellow
            Write-Host $localCommits
        }
        Get-CommandText 'git' @('var', 'GIT_AUTHOR_IDENT') 'Configure git user.name e user.email antes de publicar' | Out-Null

        $pubspecContent = [System.IO.File]::ReadAllText($pubspecPath)
        $versionMatch = [regex]::Match($pubspecContent, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
        if (-not $versionMatch.Success) {
            throw 'Nao foi possivel identificar a versao atual em cinemax/pubspec.yaml.'
        }

        $currentVersion = $versionMatch.Groups[1].Value
        $currentBuild = [int]$versionMatch.Groups[2].Value
        $newBuild = $currentBuild
        $currentTag = "v$currentVersion"
        $targetVersion = if ($Version) { $Version } else { Get-NextVersion $currentVersion }
        if ($targetVersion -notmatch '^\d+\.\d+\.\d+$') {
            throw "Versao invalida: $targetVersion. Use o formato X.Y.Z."
        }

        $currentTagLines = @(Get-RemoteTagLines $currentTag)
        $currentRelease = if ($currentTagLines.Count -gt 0) { Get-ReleaseInfo $currentTag } else { $null }
        $currentAssetName = "CiNey-$currentTag.apk"
        $currentAssetExists = $currentRelease -and @($currentRelease.assets | Where-Object { $_.name -eq $currentAssetName -and $_.state -eq 'uploaded' }).Count -gt 0
        $retryCurrentTag = $false
        $pushLocalCurrentTag = $false

        if (-not $Version -and $currentTagLines.Count -gt 0 -and -not $currentAssetExists) {
            $targetVersion = $currentVersion
            $retryCurrentTag = $true
        } elseif (-not $Version -and $currentTagLines.Count -eq 0 -and (git tag --list $currentTag)) {
            $localTagCommit = Get-CommandText 'git' @('rev-parse', "$currentTag^{commit}") 'Falha ao ler a tag local'
            $headCommit = Get-CommandText 'git' @('rev-parse', 'HEAD') 'Falha ao ler o commit atual'
            if ($localTagCommit -ne $headCommit) {
                throw "A tag local $currentTag nao aponta para HEAD e nao existe no remoto. Resolva essa tag antes de publicar."
            }
            $targetVersion = $currentVersion
            $retryCurrentTag = $true
            $pushLocalCurrentTag = $true
        }

        $targetTag = "v$targetVersion"
        $targetAssetName = "CiNey-$targetTag.apk"
        if (-not $retryCurrentTag -and [version]$targetVersion -le [version]$currentVersion) {
            throw "A versao alvo $targetVersion precisa ser maior que a versao atual $currentVersion."
        }
        if ($retryCurrentTag) {
            if ($pushLocalCurrentTag) {
                $targetCommit = Get-CommandText 'git' @('rev-parse', "$currentTag^{commit}") 'Falha ao ler o commit da tag'
            } else {
                $peeledLine = $currentTagLines | Where-Object { $_ -match "refs/tags/$([regex]::Escape($currentTag))\^\{\}$" } | Select-Object -First 1
                if (-not $peeledLine) {
                    Invoke-Checked 'git' @('fetch', '--quiet', 'origin', "refs/tags/$currentTag:refs/tags/$currentTag") 'Falha ao buscar a tag para retentativa'
                    $targetCommit = Get-CommandText 'git' @('rev-parse', "$currentTag^{commit}") 'Falha ao ler o commit da tag'
                } else {
                    $targetCommit = ($peeledLine -split '\s+')[0]
                }
            }
            $headCommit = Get-CommandText 'git' @('rev-parse', 'HEAD') 'Falha ao ler o commit atual'
            if ($targetCommit -ne $headCommit) {
                throw "A tag $currentTag ja existe, mas nao aponta para HEAD. Recusei repetir a publicacao de outro codigo."
            }
        } else {
            $targetTagLines = @(Get-RemoteTagLines $targetTag)
            if ($targetTagLines.Count -gt 0 -or (git tag --list $targetTag)) {
                throw "A tag $targetTag ja existe. O script nao sobrescreve tags/releases."
            }
        }

        Write-Host '===================================================' -ForegroundColor Cyan
        Write-Host '  CiNey - Publicacao Mobile em um clique' -ForegroundColor Cyan
        Write-Host "  Branch: $branch (validada contra origin/main)" -ForegroundColor Gray
        Write-Host "  Versao atual: $currentVersion+$currentBuild" -ForegroundColor Gray
        Write-Host "  Versao alvo: $targetTag" -ForegroundColor Yellow
        Write-Host '  Build assinado e release: GitHub Actions' -ForegroundColor Gray
        Write-Host '===================================================' -ForegroundColor Cyan

        if ($PreflightOnly) {
            Write-Host 'Preflight da main: nenhum commit, tag, push ou workflow sera criado/disparado.' -ForegroundColor Gray
            $workingTree = git status --porcelain --untracked-files=all
            if ($workingTree) {
                Write-Host 'Preflight OK na main; antes de publicar, faca commit das alteracoes:' -ForegroundColor Yellow
                $workingTree | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host 'Preflight OK na main; arvore limpa e sem commits remotos pendentes de integracao.' -ForegroundColor Green
            }
            return
        }

        $workingTree = git status --porcelain --untracked-files=all
        if ($workingTree) {
            Write-Host 'Existem alteracoes locais. Faca commit antes de publicar:' -ForegroundColor Yellow
            $workingTree | ForEach-Object { Write-Host "  $_" }
            throw 'A publicacao foi cancelada para nao incluir alteracoes inesperadas.'
        }

        if (-not $retryCurrentTag) {
            Push-Location $projectDir
            try {
                Write-Host "`nExecutando flutter analyze..." -ForegroundColor Cyan
                Invoke-Checked 'flutter' @('analyze') 'flutter analyze falhou'
                Write-Host "`nExecutando testes focados do fluxo de reproducao..." -ForegroundColor Cyan
                Invoke-Checked 'flutter' @('test', '--no-pub', 'test/details_auto_play_test.dart', 'test/player_episode_continuity_test.dart') 'Testes focados falharam'
                Write-Host "`nExecutando a suite completa do Flutter..." -ForegroundColor Cyan
                Invoke-Checked 'flutter' @('test', '--no-pub') 'Suite completa do Flutter falhou'
                Write-Host "`nExecutando testes Node da ponte de embeds..." -ForegroundColor Cyan
                Invoke-Checked 'node' @('--test', 'test/embed_bridge_test.cjs', 'test/embed_media_observer_test.cjs', 'test/embed_startup_test.cjs') 'Testes Node falharam'
            } finally {
                Pop-Location
            }

            $newBuild = $currentBuild + 1
            $newVersionLine = "version: $targetVersion+$newBuild"
            $updatedPubspec = [regex]::Replace($pubspecContent, '(?m)^version:\s*.*$', $newVersionLine, 1)
            $inventoryContent = [System.IO.File]::ReadAllText($inventoryPath)
            $inventoryPattern = '(?m)^\| Mobile \| `mobile/` \| `CiNey-v\d+\.\d+\.\d+\.apk` \|[ \t]*(?=\r?$)'
            if (-not [regex]::IsMatch($inventoryContent, $inventoryPattern)) {
                throw 'Nao encontrei a linha da variante Mobile em releases/README.md.'
            }
            $inventoryRow = "| Mobile | ``mobile/`` | ``CiNey-$targetTag.apk`` |"
            $updatedInventory = [regex]::Replace($inventoryContent, $inventoryPattern, $inventoryRow, 1)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, $utf8NoBom)
            [System.IO.File]::WriteAllText($inventoryPath, $updatedInventory, $utf8NoBom)

            Invoke-Checked 'git' @('add', '--', 'cinemax/pubspec.yaml', 'releases/README.md') 'Falha ao preparar arquivos da release'
            Invoke-Checked 'git' @('commit', '-m', "chore(release): bump version to $targetTag [skip ci]") 'Falha ao criar commit da versao'
            Invoke-Checked 'git' @('tag', '-a', $targetTag, '-m', "Release $targetTag") 'Falha ao criar tag'
        }

        # Tambem na retentativa, main precisa receber o commit antes da tag.
        Invoke-Checked 'git' @('push', 'origin', 'main') 'Push da main recusado; nenhuma tag foi enviada nesta tentativa. Resolva a protecao ou divergencia e execute novamente; a tag local foi preservada'
        if (-not $retryCurrentTag -or $pushLocalCurrentTag) {
            Invoke-Checked 'git' @('push', 'origin', $targetTag) 'Falha ao enviar a tag; main ja recebeu o commit. Execute novamente para retomar'
        }

        $tagCommit = Get-CommandText 'git' @('rev-parse', "$targetTag^{commit}") 'Falha ao ler o commit da tag'
        $runsJson = Get-CommandText 'gh' @('run', 'list', '--repo', $repoSlug, '--workflow', $workflowFile, '--branch', $targetTag, '--limit', '10', '--json', 'databaseId,headSha,status') 'Falha ao consultar execucoes recentes'
        $existingRun = @(($runsJson | ConvertFrom-Json) | Where-Object { $_.headSha -eq $tagCommit -and $_.status -in @('queued', 'in_progress') } | Select-Object -First 1)

        if ($existingRun.Count -gt 0) {
            $runId = [string]$existingRun[0].databaseId
            Write-Host "`nJa existe um build ativo para $targetTag; acompanhando a execucao $runId." -ForegroundColor Yellow
        } else {
            if (-not $Notes) {
                $previousTag = Get-CommandText 'git' @('tag', '--list', 'v*', '--sort=-version:refname') 'Falha ao listar tags'
                $previousTag = @($previousTag -split "`n" | Where-Object { $_ -and $_ -ne $targetTag } | Select-Object -First 1)
                $changeLines = if ($previousTag.Count -gt 0) {
                    Get-CommandText 'git' @('log', "$($previousTag[0])..$targetTag", '--pretty=format:%s', '-n', '20') 'Falha ao montar notas da release'
                } else {
                    ''
                }
                $changeNotes = @($changeLines -split "`n" | Where-Object { $_ -and $_ -notmatch '^chore\(release\):' })
                $Notes = if ($changeNotes.Count -gt 0) { ($changeNotes | ForEach-Object { "- $_" }) -join "`n" } else { '- Correcao de erros e melhorias de estabilidade.' }
            }

            $json = @{
                version_tag = $targetTag
                release_title = "CiNey $targetTag"
                release_notes = $Notes
            } | ConvertTo-Json -Compress
            # O GitHub informa createdAt com precisao de segundos.
            $dispatchStartedAt = [DateTimeOffset]::UtcNow
            $dispatchStartedAt = $dispatchStartedAt.AddTicks(-($dispatchStartedAt.Ticks % [TimeSpan]::TicksPerSecond))
            # Windows PowerShell 5.1 usa ASCII no pipeline nativo por padrao.
            $previousOutputEncoding = $OutputEncoding
            try {
                $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
                $dispatchOutput = $json | gh workflow run $workflowFile --repo $repoSlug --ref $targetTag --json 2>&1
                $dispatchExitCode = $LASTEXITCODE
            } finally {
                $OutputEncoding = $previousOutputEncoding
            }
            if ($dispatchExitCode -ne 0) {
                throw 'Falha ao iniciar GitHub Actions; tag preservada para retentativa.'
            }
            $dispatchText = ($dispatchOutput | ForEach-Object { "$_" }) -join "`n"
            Write-Host $dispatchText
            $runMatch = [regex]::Match($dispatchText, '/actions/runs/(\d+)')
            if ($runMatch.Success) {
                $runId = $runMatch.Groups[1].Value
            } else {
                $runId = $null
                for ($attempt = 1; $attempt -le 6; $attempt++) {
                    $dispatchedRunsJson = Get-CommandText 'gh' @('run', 'list', '--repo', $repoSlug, '--workflow', $workflowFile, '--branch', $targetTag, '--event', 'workflow_dispatch', '--limit', '20', '--json', 'databaseId,headSha,createdAt') 'Falha ao localizar a execucao disparada'
                    $dispatchedRun = @(($dispatchedRunsJson | ConvertFrom-Json) | Where-Object {
                        $_.headSha -eq $tagCommit -and [DateTimeOffset]$_.createdAt -ge $dispatchStartedAt
                    } | Sort-Object createdAt | Select-Object -First 1)
                    if ($dispatchedRun.Count -gt 0) {
                        $runId = [string]$dispatchedRun[0].databaseId
                        break
                    }
                    if ($attempt -lt 6) { Start-Sleep -Seconds 5 }
                }
                if (-not $runId) {
                    throw "O workflow foi solicitado, mas nao encontrei uma execucao nova para o commit da tag. Veja https://github.com/$repoSlug/actions; a tag foi preservada."
                }
            }
        }

        Write-Host "`nAguardando build assinado e publicacao do APK..." -ForegroundColor Cyan
        Invoke-Checked 'gh' @('run', 'watch', $runId, '--repo', $repoSlug, '--exit-status') 'O GitHub Actions falhou; tag preservada para retentativa'

        $releaseJson = Get-CommandText 'gh' @('release', 'view', $targetTag, '--repo', $repoSlug, '--json', 'tagName,assets,url') 'A release nao foi encontrada apos o build'
        $releaseInfo = $releaseJson | ConvertFrom-Json
        $asset = @($releaseInfo.assets | Where-Object { $_.name -eq $targetAssetName -and $_.state -eq 'uploaded' } | Select-Object -First 1)
        if ($asset.Count -eq 0 -or $asset[0].size -le 0) {
            throw "A release $targetTag terminou sem o asset $targetAssetName."
        }

        $downloadDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("ciney-release-download-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
        try {
            Invoke-Checked 'gh' @('release', 'download', $targetTag, '--repo', $repoSlug, '--pattern', $targetAssetName, '--dir', $downloadDirectory) 'Falha ao baixar o APK publicado'
            $downloadedApk = Join-Path $downloadDirectory $targetAssetName
            if (-not (Test-Path $downloadedApk) -or (Get-Item $downloadedApk).Length -ne [long]$asset[0].size) {
                throw 'O APK baixado nao corresponde ao tamanho informado pelo GitHub.'
            }
            $downloadHash = (Get-FileHash $downloadedApk -Algorithm SHA256).Hash.ToLowerInvariant()
            $digestProperty = $asset[0].PSObject.Properties['digest']
            if ($digestProperty -and $digestProperty.Value) {
                $digest = [string]$digestProperty.Value
                if ($digest -notmatch '^sha256:([0-9a-fA-F]{64})$') {
                    throw 'O digest do asset nao e um SHA-256 valido.'
                }
                $expectedHash = $Matches[1].ToLowerInvariant()
            } else {
                $checksumName = "$targetAssetName.sha256"
                $checksumAsset = @($releaseInfo.assets | Where-Object { $_.name -eq $checksumName -and $_.state -eq 'uploaded' })
                if ($checksumAsset.Count -ne 1) {
                    throw "A release nao fornece digest nem $checksumName; nao e possivel validar o APK."
                }
                Invoke-Checked 'gh' @('release', 'download', $targetTag, '--repo', $repoSlug, '--pattern', $checksumName, '--dir', $downloadDirectory) 'Falha ao baixar o arquivo SHA-256'
                $checksumText = [System.IO.File]::ReadAllText((Join-Path $downloadDirectory $checksumName))
                $checksumPattern = '\A([0-9a-fA-F]{64}) [ *]' + [regex]::Escape($targetAssetName) + '(?:\r?\n)?\z'
                $checksumMatch = [regex]::Match($checksumText, $checksumPattern)
                if (-not $checksumMatch.Success) {
                    throw "O arquivo $checksumName nao contem um SHA-256 valido para $targetAssetName."
                }
                $expectedHash = $checksumMatch.Groups[1].Value.ToLowerInvariant()
            }
            if ($expectedHash -ne $downloadHash) {
                throw 'O SHA-256 do APK baixado diverge do asset publicado; mantive a copia local anterior.'
            }

            New-Item -ItemType Directory -Path $releaseDirectory -Force | Out-Null
            $destination = Join-Path $releaseDirectory $targetAssetName
            $pendingDestination = "$destination.pending"
            Copy-Item $downloadedApk $pendingDestination -Force
            Move-Item $pendingDestination $destination -Force
            $targetSemVer = [version]$targetVersion
            Get-ChildItem $releaseDirectory -Filter 'CiNey-v*.apk' -File | ForEach-Object {
                if ($_.Name -match '^CiNey-v(\d+\.\d+\.\d+)\.apk$' -and [version]$matches[1] -lt $targetSemVer) {
                    Remove-Item $_.FullName -Force
                }
            }

            Write-Host "`nRELEASE PUBLICADA E APK VALIDADO." -ForegroundColor Green
            Write-Host "Versao: $targetTag ($newBuild)" -ForegroundColor Green
            Write-Host "Arquivo: $destination" -ForegroundColor Green
            Write-Host "SHA-256: $downloadHash" -ForegroundColor Gray
            Write-Host "GitHub: $($releaseInfo.url)" -ForegroundColor Yellow
        } finally {
            Remove-Item $downloadDirectory -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host $_ -ForegroundColor Red
        exit 1
    } finally {
        Pop-Location
    }
