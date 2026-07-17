param(
    [int]$WorkCount = 5000,
    [string]$OutputName = "latest-5000",
    [string]$Gpu = "H100",
    [int]$MaxBatchTokens = 16384,
    [int]$BatchSize = 256,
    [int]$WorkBufferSize = 64,
    [int]$WindowPages = 3,
    [int]$StridePages = 2,
    [switch]$KeepRemote
)

$ErrorActionPreference = "Stop"
$runtimeDirectory = Join-Path $PSScriptRoot ".runtime"
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $runtimeDirectory "modal-$timestamp.log"

$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"
$env:TERM = "dumb"

$arguments = @(
    "-u", "-m", "modal", "run", "-q", (Join-Path $PSScriptRoot "embed-modal.py"),
    "--work-count", $WorkCount,
    "--output-name", $OutputName,
    "--gpu", $Gpu,
    "--max-batch-tokens", $MaxBatchTokens,
    "--batch-size", $BatchSize,
    "--work-buffer-size", $WorkBufferSize,
    "--window-pages", $WindowPages,
    "--stride-pages", $StridePages
)
if ($KeepRemote) {
    $arguments += "--keep-remote"
}

Write-Host "Logging local and streamed Modal output to $logPath"
$quotedArguments = $arguments | ForEach-Object {
    '"' + ([string]$_).Replace('"', '\"') + '"'
}
$commandLine = "python3 $($quotedArguments -join ' ') 2>&1"
& $env:ComSpec /d /s /c $commandLine | Tee-Object -FilePath $logPath
$exitCode = $LASTEXITCODE
Write-Host "Modal run exited with code $exitCode. Log: $logPath"
exit $exitCode
