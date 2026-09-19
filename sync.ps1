$ErrorActionPreference = "Stop"

if (-not $env:CANVAS_TOKEN) {
    throw "CANVAS_TOKEN nao esta configurado nesta sessao do PowerShell."
}

$baseUrl = "https://puc-campinas.instructure.com/api/v1"
$headers = @{ Authorization = "Bearer $env:CANVAS_TOKEN" }
$startDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$endDate = (Get-Date).AddMonths(6).ToUniversalTime().ToString("yyyy-MM-dd")
$uri = "$baseUrl/planner/items?start_date=$startDate&end_date=$endDate&per_page=100"

$courses = Invoke-RestMethod -Headers $headers -Uri "$baseUrl/users/self/courses?enrollment_state=active&per_page=100"
$courseNames = @{}
foreach ($course in $courses) {
    $courseNames[[string]$course.id] = [string]$course.name
}

$items = Invoke-RestMethod -Headers $headers -Uri $uri
$output = Join-Path $PSScriptRoot "canvas-items.tsv"

$lines = foreach ($item in $items) {
    $plannable = $item.plannable
    $type = [string]$item.plannable_type
    $courseId = [string]$item.course_id
    $courseName = [string]$courseNames[$courseId]
    $title = [string]$plannable.title
    $dueAt = [string]$plannable.due_at
    $url = ""

    if ($type -eq "assignment" -and $plannable.id) {
        $url = "https://puc-campinas.instructure.com/courses/$courseId/assignments/$($plannable.id)"
    } elseif ($type -eq "quiz" -and $plannable.id) {
        $url = "https://puc-campinas.instructure.com/courses/$courseId/quizzes/$($plannable.id)"
    }

    $courseName = $courseName.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ")
    $title = $title.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ")
    $dueAt = $dueAt.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ")
    $url = $url.Replace("`t", " ").Replace("`r", " ").Replace("`n", " ")

    "$type`t$courseId`t$($plannable.id)`t$courseName`t$title`t$dueAt`t$url"
}

"type`tcourse_id`ttask_id`tcourse_name`ttitle`tdue_at`thtml_url" | Set-Content -LiteralPath $output -Encoding UTF8
$lines | Add-Content -LiteralPath $output -Encoding UTF8

Write-Output "Itens sincronizados: $($items.Count)"
Write-Output "Arquivo gerado: $output"
