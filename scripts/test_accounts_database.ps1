param([string]$Image = 'postgres:17-alpine')

$ErrorActionPreference = 'Stop'
$testRoot = Split-Path -Parent $PSScriptRoot
$testContainer = 'ciney-accounts-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)

function Invoke-TestSql([string]$RelativePath) {
    $sql = Get-Content -Raw -Encoding utf8 -LiteralPath (Join-Path $testRoot $RelativePath)
    $sql | docker exec -i $testContainer psql -U postgres -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw "Falha em $RelativePath" }
}

try {
    # No host ports or workspace volumes; this password belongs only to the test container.
    docker run --detach --name $testContainer --env POSTGRES_PASSWORD=ciney-local-test-only $Image -c wal_level=logical
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível iniciar o PostgreSQL de teste.' }
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        docker exec $testContainer pg_isready -U postgres 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'O PostgreSQL de teste não ficou pronto.' }
    Invoke-TestSql 'supabase/tests/bootstrap_local.sql'
    Invoke-TestSql 'supabase/migrations/202610070001_accounts_and_favorites.sql'
    Invoke-TestSql 'supabase/migrations/202610070002_tv_qr_pairing.sql'
    Invoke-TestSql 'supabase/tests/accounts_rls.sql'
}
finally {
    # Remove only the uniquely named container and its disposable anonymous volume.
    docker rm --force --volumes $testContainer | Out-Null
}
