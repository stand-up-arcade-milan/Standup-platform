param([switch]$SkipPostman)

$ErrorActionPreference = 'Stop'
$projectName = 'standup-it-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$apiPort = $null
$webPort = $null
$postgresPort = $null
$apiUrl = $null
$wasStarted = $false
$variables = @('POSTGRES_USER','POSTGRES_PASSWORD','POSTGRES_APP_PASSWORD','POSTGRES_PORT','API_PORT','WEB_PORT','ARCADE_JWT_SECRET','ARCADE_AUTH_LOCAL_TOKENS_ENABLED','API_BASE_URL')
$oldEnvironment = @{}
foreach ($name in $variables) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

function Invoke-ProjectCompose([string[]]$ComposeArgs) {
    & docker compose -p $projectName @ComposeArgs
    if ($LASTEXITCODE -ne 0) { throw "docker compose $($ComposeArgs -join ' ') failed with exit code $LASTEXITCODE" }
}

try {
    $env:POSTGRES_USER = 'ci_runner'
    $env:POSTGRES_PASSWORD = 'ci-only-password'
    $env:POSTGRES_APP_PASSWORD = 'ci-app-only-password'
    # Docker asks Windows for available ephemeral ports instead of using a reserved range.
    $env:POSTGRES_PORT = '0'
    $env:API_PORT = '0'
    $env:WEB_PORT = '0'
    $env:ARCADE_JWT_SECRET = 'local-integration-secret-change-me-32-bytes'
    $env:ARCADE_AUTH_LOCAL_TOKENS_ENABLED = 'true'
    $env:API_BASE_URL = $apiUrl

    Write-Host "Avvio stack Compose isolato $projectName con porte locali assegnate da Docker."
    Invoke-ProjectCompose @('config', '--quiet')
    $wasStarted = $true
    Invoke-ProjectCompose @('up', '-d', '--build')
    $apiBinding = Invoke-ProjectCompose @('port', 'backend', '8080')
    $webBinding = Invoke-ProjectCompose @('port', 'frontend', '5173')
    $dbBinding = Invoke-ProjectCompose @('port', 'db', '5432')
    $apiPort = ($apiBinding -split ':')[-1].Trim()
    $webPort = ($webBinding -split ':')[-1].Trim()
    $postgresPort = ($dbBinding -split ':')[-1].Trim()
    $apiUrl = "http://127.0.0.1:$apiPort/api/v1"
    $env:API_BASE_URL = $apiUrl
    Write-Host "Porte assegnate: API $apiPort, web $webPort, PostgreSQL $postgresPort."

    $ready = $false
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        try {
            $healthText = curl.exe --silent --show-error --fail --max-time 3 "http://127.0.0.1:$apiPort/actuator/health"
            $healthExit = $LASTEXITCODE
            $pageStatus = curl.exe --silent --show-error --output NUL --write-out '%{http_code}' --max-time 3 "http://127.0.0.1:$webPort/"
            $pageExit = $LASTEXITCODE
            $health = $healthText | ConvertFrom-Json
            if ($healthExit -eq 0 -and $pageExit -eq 0 -and $health.status -eq 'UP' -and $pageStatus -eq '200') { $ready = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) { Invoke-ProjectCompose @('ps'); Invoke-ProjectCompose @('logs', '--no-color'); throw 'I servizi non sono diventati disponibili entro tre minuti.' }

    $fixture = (Resolve-Path 'scripts/test/integration-fixture.sql').Path
    Invoke-ProjectCompose @('cp', $fixture, 'db:/tmp/integration-fixture.sql')
    Invoke-ProjectCompose @('exec', '-T', 'db', 'sh', '-lc', 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/integration-fixture.sql')

    node scripts/test/api-integration.mjs
    if ($LASTEXITCODE -ne 0) { throw 'La suite API integrata non e'' passata.' }

    if (-not $SkipPostman) {
        $badToken = node scripts/test/make-token.mjs BAD
        if ($LASTEXITCODE -ne 0) { throw 'Non e'' stato possibile creare il token sintetico BAD.' }
        npx --yes newman@6.2.2 run postman/standup-platform-bid-bad.postman_collection.json `
            --env-var "apiBaseUrl=$apiUrl" `
            --env-var "badToken=$badToken" `
            --reporters cli
        if ($LASTEXITCODE -ne 0) { throw 'La collection Postman/Newman non e'' passata.' }
    }
    Write-Host "PASS: suite integrata completa. Il volume PostgreSQL isolato $projectName e'' stato conservato."
}
finally {
    if ($wasStarted) {
        & docker compose -p $projectName stop --timeout 10 | Out-Null
    }
    foreach ($name in $variables) {
        [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], 'Process')
    }
}
