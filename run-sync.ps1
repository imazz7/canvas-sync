$ErrorActionPreference = "Stop"

$projectPath = $PSScriptRoot
$gccCommand = Get-Command gcc.exe -ErrorAction SilentlyContinue
$gccPath = if ($gccCommand) { $gccCommand.Source } else { "C:\msys64\ucrt64\bin\gcc.exe" }
$calendarUrl = "https://calendar.google.com/calendar/u/0/r/month"
$logPath = Join-Path $projectPath "sync.log"
$startedAt = Get-Date

function Write-Log {
    param([string]$Message)

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -LiteralPath $logPath -Value "[$timestamp] $Message" -Encoding UTF8
}

Write-Log "INICIO da sincronizacao."

try {
    if (-not $env:CANVAS_TOKEN) {
        $env:CANVAS_TOKEN = [Environment]::GetEnvironmentVariable("CANVAS_TOKEN", "User")
    }

    if (-not $env:CANVAS_TOKEN) {
        throw "CANVAS_TOKEN nao esta configurado para esta tarefa."
    }

    Set-Location -LiteralPath $projectPath

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\sync.ps1" 2>&1 |
        ForEach-Object { Write-Log ([string]$_) }
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao sincronizar dados do Canvas. Codigo: $LASTEXITCODE"
    }

    if (-not (Test-Path -LiteralPath $gccPath)) {
        throw "GCC nao encontrado. Instale o GCC e adicione-o ao PATH."
    }

    & $gccPath -std=c17 -Wall -Wextra -pedantic ".\calendar.c" -o ".\calendar.exe" 2>&1 |
        ForEach-Object { Write-Log ([string]$_) }
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao compilar calendar.c. Codigo: $LASTEXITCODE"
    }

    & ".\calendar.exe" 2>&1 |
        ForEach-Object { Write-Log ([string]$_) }
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao gerar canvas-events.ics. Codigo: $LASTEXITCODE"
    }

    if (Test-Path -LiteralPath ".\client_secret.json") {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\google-sync.ps1" 2>&1 |
            ForEach-Object { Write-Log ([string]$_) }
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao sincronizar com o Google Calendar. Codigo: $LASTEXITCODE"
        }
    } else {
        Write-Log "AVISO: client_secret.json nao encontrado; Google Calendar ignorado."
    }

    Start-Process $calendarUrl
    Write-Log "Calendario Google aberto no navegador padrao."

    $duration = (Get-Date) - $startedAt
    Write-Log ("FIM com sucesso. Duracao: {0:N1}s." -f $duration.TotalSeconds)
    exit 0
} catch {
    $duration = (Get-Date) - $startedAt
    Write-Log ("FIM com erro. Duracao: {0:N1}s. Mensagem: {1}" -f $duration.TotalSeconds, $_.Exception.Message)
    exit 1
}
