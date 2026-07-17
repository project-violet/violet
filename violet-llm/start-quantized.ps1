param(
    [string]$LlamaServer = "",
    [switch]$EmbeddingOnly,
    [switch]$RerankerOnly
)

$ErrorActionPreference = "Stop"
if ($EmbeddingOnly -and $RerankerOnly) {
    throw "-EmbeddingOnly and -RerankerOnly cannot be used together."
}
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtime = Join-Path $root ".runtime"
New-Item -ItemType Directory -Force -Path $runtime | Out-Null

$bundledServer = Join-Path $root ".tools\llama-cuda\llama-server.exe"
if (-not $LlamaServer) {
    $LlamaServer = if (Test-Path -LiteralPath $bundledServer) { $bundledServer } else { "llama-server" }
}
$server = Get-Command $LlamaServer -ErrorAction Stop
$embeddingOut = Join-Path $runtime "embedding.out.log"
$embeddingErr = Join-Path $runtime "embedding.err.log"
$rerankerOut = Join-Path $runtime "reranker.out.log"
$rerankerErr = Join-Path $runtime "reranker.err.log"

$embeddingArgs = @(
    "-hf", "Qwen/Qwen3-Embedding-4B-GGUF:Q5_K_M",
    "--embedding", "--pooling", "last",
    "--host", "127.0.0.1", "--port", "8081",
    "--n-gpu-layers", "99", "--ctx-size", "2048",
    "--batch-size", "2048", "--ubatch-size", "2048"
)
$rerankerArgs = @(
    "-hf", "Voodisss/Qwen3-Reranker-4B-GGUF-llama_cpp:Q4_K_M",
    "--reranking", "--pooling", "rank",
    "--host", "127.0.0.1", "--port", "8082",
    "--n-gpu-layers", "99", "--ctx-size", "2048",
    "--batch-size", "2048", "--ubatch-size", "2048"
)

$statePath = Join-Path $runtime "servers.json"
$oldEmbeddingPid = $null
$oldRerankerPid = $null
if (Test-Path -LiteralPath $statePath) {
    $oldState = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $oldEmbeddingPid = $oldState.embedding_pid
    $oldRerankerPid = $oldState.reranker_pid
}

$embedding = $null
$reranker = $null
try {
    if (-not $RerankerOnly) {
        $embedding = Start-Process -FilePath $server.Source -ArgumentList $embeddingArgs `
            -RedirectStandardOutput $embeddingOut -RedirectStandardError $embeddingErr `
            -WindowStyle Hidden -PassThru
    }
    if (-not $EmbeddingOnly) {
        $reranker = Start-Process -FilePath $server.Source -ArgumentList $rerankerArgs `
            -RedirectStandardOutput $rerankerOut -RedirectStandardError $rerankerErr `
            -WindowStyle Hidden -PassThru
    }
} catch {
    $startedProcessIds = @()
    if ($null -ne $embedding) { $startedProcessIds += $embedding.Id }
    if ($null -ne $reranker) { $startedProcessIds += $reranker.Id }
    if ($startedProcessIds.Count -gt 0) {
        Stop-Process -Id $startedProcessIds -Force -ErrorAction SilentlyContinue
    }
    throw
}

@{
    embedding_pid = if ($null -ne $embedding) { $embedding.Id } else { $oldEmbeddingPid }
    reranker_pid = if ($null -ne $reranker) { $reranker.Id } else { $oldRerankerPid }
} | ConvertTo-Json | Set-Content -Encoding utf8 $statePath

if ($null -ne $embedding) {
    Write-Host "Embedding server PID $($embedding.Id): http://127.0.0.1:8081"
}
if ($null -ne $reranker) {
    Write-Host "Reranker server PID $($reranker.Id): http://127.0.0.1:8082"
}
Write-Host "First startup downloads the required model(s). Logs are under $runtime"

function Test-Server([string]$Url) {
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

try {
    $deadline = (Get-Date).AddMinutes(20)
    $lastNotice = Get-Date
    while ((Get-Date) -lt $deadline) {
        if ($null -ne $embedding -and $embedding.HasExited) {
            throw "Embedding server exited with code $($embedding.ExitCode). Check $embeddingErr"
        }
        if ($null -ne $reranker -and $reranker.HasExited) {
            throw "Reranker server exited with code $($reranker.ExitCode). Check $rerankerErr"
        }
        $embeddingReady = $RerankerOnly -or (Test-Server "http://127.0.0.1:8081/health")
        $rerankerReady = $EmbeddingOnly -or (Test-Server "http://127.0.0.1:8082/health")
        if ($embeddingReady -and $rerankerReady) {
            if ($EmbeddingOnly) {
                Write-Host "Embedding server is ready."
            } elseif ($RerankerOnly) {
                Write-Host "Reranker server is ready."
            } else {
                Write-Host "Embedding and reranker servers are ready."
            }
            break
        }
        if (((Get-Date) - $lastNotice).TotalSeconds -ge 10) {
            Write-Host "Waiting for model servers (models may still be downloading)..."
            $lastNotice = Get-Date
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not ($embeddingReady -and $rerankerReady)) {
        throw "Timed out waiting for model servers. Check logs under $runtime"
    }
} catch {
    $startedProcessIds = @()
    if ($null -ne $embedding) {
        $startedProcessIds += $embedding.Id
    }
    if ($null -ne $reranker) {
        $startedProcessIds += $reranker.Id
    }
    if ($startedProcessIds.Count -gt 0) {
        Stop-Process -Id $startedProcessIds -Force -ErrorAction SilentlyContinue
    }
    throw
}
