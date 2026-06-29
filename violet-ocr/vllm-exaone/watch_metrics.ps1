param(
  [string]$BaseUrl = "http://localhost:8001",
  [int]$IntervalSeconds = 5,
  [int]$Samples = 0
)

$ErrorActionPreference = "Stop"

function Get-VllmMetricsText {
  (Invoke-WebRequest "$BaseUrl/metrics" -UseBasicParsing).Content
}

function Get-MetricSum {
  param(
    [string]$MetricsText,
    [string]$Name
  )

  $escapedName = [regex]::Escape($Name)
  $values = $MetricsText -split "`n" |
    Where-Object { $_ -match "^$escapedName(\{| )" -and $_ -notmatch "^#" } |
    ForEach-Object {
      $parts = $_.Trim() -split "\s+"
      if ($parts.Count -ge 2) {
        [double]$parts[-1]
      }
    }

  if ($null -eq $values) {
    return 0.0
  }

  return ($values | Measure-Object -Sum).Sum
}

function Get-MetricMax {
  param(
    [string]$MetricsText,
    [string]$Name
  )

  $escapedName = [regex]::Escape($Name)
  $values = $MetricsText -split "`n" |
    Where-Object { $_ -match "^$escapedName(\{| )" -and $_ -notmatch "^#" } |
    ForEach-Object {
      $parts = $_.Trim() -split "\s+"
      if ($parts.Count -ge 2) {
        [double]$parts[-1]
      }
    }

  if ($null -eq $values) {
    return 0.0
  }

  return ($values | Measure-Object -Maximum).Maximum
}

Write-Host "time     out_tok/s in_tok/s total_tok/s running waiting kv_cache%"

$sampleCount = 0
while ($true) {
  $first = Get-VllmMetricsText
  $gen1 = Get-MetricSum $first "vllm:generation_tokens_total"
  $prompt1 = Get-MetricSum $first "vllm:prompt_tokens_total"

  Start-Sleep -Seconds $IntervalSeconds

  $second = Get-VllmMetricsText
  $gen2 = Get-MetricSum $second "vllm:generation_tokens_total"
  $prompt2 = Get-MetricSum $second "vllm:prompt_tokens_total"
  $running = Get-MetricSum $second "vllm:num_requests_running"
  $waiting = Get-MetricSum $second "vllm:num_requests_waiting"
  $kvCache = Get-MetricMax $second "vllm:kv_cache_usage_perc"

  $outTps = ($gen2 - $gen1) / $IntervalSeconds
  $inTps = ($prompt2 - $prompt1) / $IntervalSeconds
  $totalTps = $outTps + $inTps

  "{0:HH:mm:ss} {1,9:N1} {2,8:N1} {3,11:N1} {4,7:N0} {5,7:N0} {6,8:N1}" -f `
    (Get-Date), $outTps, $inTps, $totalTps, $running, $waiting, ($kvCache * 100.0)

  if ($Samples -gt 0) {
    $sampleCount += 1
    if ($sampleCount -ge $Samples) {
      break
    }
  }
}
