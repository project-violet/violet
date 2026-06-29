$ErrorActionPreference = "Continue"

Write-Host "== vLLM processes =="
wsl -d Ubuntu-24.04 -- bash -lc "pgrep -af 'vllm|EngineCore' || true"

Write-Host ""
Write-Host "== /v1/models =="
try {
  Invoke-WebRequest -Uri http://localhost:8001/v1/models -UseBasicParsing -TimeoutSec 5 |
    Select-Object -ExpandProperty Content
} catch {
  Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "== GPU memory =="
wsl -d Ubuntu-24.04 -- nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv,noheader
