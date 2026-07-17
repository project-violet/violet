$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = Join-Path $root ".runtime\servers.json"

if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Host "No quantized server state found."
    exit 0
}

$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
foreach ($processId in @($state.embedding_pid, $state.reranker_pid)) {
    if ($null -eq $processId) {
        continue
    }
    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.ProcessName -like "llama-server*") {
        Stop-Process -Id $processId
        Write-Host "Stopped PID $processId"
    }
}
Remove-Item -LiteralPath $statePath -Force
