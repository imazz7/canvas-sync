$ErrorActionPreference = "Stop"

$projectPath = $PSScriptRoot
$clientSecretPath = Join-Path $projectPath "client_secret.json"
$tokenPath = Join-Path $projectPath "google-token.json"
$itemsPath = Join-Path $projectPath "canvas-items.tsv"
$calendarId = if ($env:GOOGLE_CALENDAR_ID) { $env:GOOGLE_CALENDAR_ID } else { "primary" }
$scope = "https://www.googleapis.com/auth/calendar"

function Get-GoogleToken {
    if (Test-Path -LiteralPath $tokenPath) {
        $saved = Get-Content -LiteralPath $tokenPath -Raw | ConvertFrom-Json
        if ($saved.refresh_token) {
            $body = @{
                client_id = $script:clientId
                client_secret = $script:clientSecret
                refresh_token = $saved.refresh_token
                grant_type = "refresh_token"
            }
            try {
                return Invoke-RestMethod -Method Post -Uri "https://oauth2.googleapis.com/token" -Body $body
            } catch {
                Remove-Item -LiteralPath $tokenPath -Force
            }
        }
    }

    $listener = [System.Net.HttpListener]::new()
    $port = 49152
    $redirectUri = "http://127.0.0.1:$port/"
    $listener.Prefixes.Add($redirectUri)
    $listener.Start()

    $query = [uri]::EscapeDataString($scope)
    $authUri = "https://accounts.google.com/o/oauth2/v2/auth?client_id=$([uri]::EscapeDataString($script:clientId))&redirect_uri=$([uri]::EscapeDataString($redirectUri))&response_type=code&scope=$query&access_type=offline&prompt=consent"
    Start-Process $authUri
    Write-Output "Aguardando autorizacao do Google no navegador..."
    $context = $listener.GetContext()
    $code = $context.Request.QueryString["code"]
    $responseText = "Autorizacao concluida. Voce pode fechar esta janela."
    $buffer = [Text.Encoding]::UTF8.GetBytes($responseText)
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $context.Response.Close()
    $listener.Stop()

    if (-not $code) {
        throw "A autorizacao do Google nao retornou um codigo."
    }

    $body = @{
        client_id = $script:clientId
        client_secret = $script:clientSecret
        code = $code
        redirect_uri = $redirectUri
        grant_type = "authorization_code"
    }
    $token = Invoke-RestMethod -Method Post -Uri "https://oauth2.googleapis.com/token" -Body $body
    $token | ConvertTo-Json | Set-Content -LiteralPath $tokenPath -Encoding UTF8
    return $token
}

if (-not (Test-Path -LiteralPath $clientSecretPath)) {
    throw "Coloque client_secret.json na pasta do projeto."
}

$clientConfig = Get-Content -LiteralPath $clientSecretPath -Raw | ConvertFrom-Json
$oauthConfig = if ($clientConfig.installed) { $clientConfig.installed } else { $clientConfig.web }
if (-not $oauthConfig.client_id -or -not $oauthConfig.client_secret) {
    throw "client_secret.json nao possui credenciais OAuth validas."
}

$script:clientId = $oauthConfig.client_id
$script:clientSecret = $oauthConfig.client_secret
$token = Get-GoogleToken
$googleHeaders = @{ Authorization = "Bearer $($token.access_token)" }

$eventsUri = "https://www.googleapis.com/calendar/v3/calendars/$([uri]::EscapeDataString($calendarId))/events"
$events = Invoke-RestMethod -Headers $googleHeaders -Uri "${eventsUri}?singleEvents=true&maxResults=2500"
$existing = @{}
foreach ($event in $events.items) {
    $canvasId = $event.extendedProperties.private.canvas_id
    if ($canvasId) {
        $existing[$canvasId] = $event.id
    }
}

$created = 0
$updated = 0
$lines = Get-Content -LiteralPath $itemsPath
foreach ($line in ($lines | Select-Object -Skip 1)) {
    $fields = $line -split "`t", 7
    if ($fields.Count -lt 7) { continue }
    $type, $courseId, $taskId, $courseName, $title, $dueAt, $url = $fields
    if (($type -ne "assignment" -and $type -ne "quiz") -or -not $dueAt -or -not $taskId) { continue }

    $canvasId = "$type-$courseId-$taskId"
    $event = @{
        summary = "$courseName - $title"
        description = "Prazo no Canvas - $courseName`n$url"
        start = @{ dateTime = $dueAt; timeZone = "UTC" }
        end = @{ dateTime = $dueAt; timeZone = "UTC" }
        source = @{ title = "Canvas LMS"; url = $url }
        extendedProperties = @{ private = @{ canvas_id = $canvasId } }
    } | ConvertTo-Json -Depth 8

    if ($existing.ContainsKey($canvasId)) {
        Invoke-RestMethod -Method Patch -Headers $googleHeaders -ContentType "application/json" -Body $event -Uri "$eventsUri/$($existing[$canvasId])" | Out-Null
        $updated++
    } else {
        Invoke-RestMethod -Method Post -Headers $googleHeaders -ContentType "application/json" -Body $event -Uri $eventsUri | Out-Null
        $created++
    }
}

Write-Output "Google Calendar: $created criados, $updated atualizados."
