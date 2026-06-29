$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Invoke-Helper {
  param(
    [string]$ScriptName,
    [string[]]$Arguments = @()
  )

  $scriptPath = Join-Path $ScriptDir $ScriptName
  & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath @Arguments
}

function Pause-Control {
  Write-Host ""
  Read-Host "Press Enter to continue"
}

function Show-Menu {
  Clear-Host
  Write-Host "vLLM EXAONE Control"
  Write-Host "=================="
  Write-Host ""
  Write-Host "[1] Start server"
  Write-Host "[2] Stop server"
  Write-Host "[3] Restart server"
  Write-Host "[4] Status"
  Write-Host "[5] Watch metrics"
  Write-Host "[6] Test chat"
  Write-Host "[7] Tail log"
  Write-Host "[0] Exit"
  Write-Host ""
}

:menu while ($true) {
  Show-Menu
  $choice = Read-Host "Select"

  switch ($choice) {
    "1" {
      Invoke-Helper "start.ps1"
      Pause-Control
    }
    "2" {
      Invoke-Helper "stop.ps1"
      Pause-Control
    }
    "3" {
      Invoke-Helper "stop.ps1"
      Start-Sleep -Seconds 2
      Invoke-Helper "start.ps1"
      Pause-Control
    }
    "4" {
      Invoke-Helper "status.ps1"
      Pause-Control
    }
    "5" {
      Write-Host "Watching metrics. Press Ctrl+C to stop."
      Invoke-Helper "watch_metrics.ps1"
      Pause-Control
    }
    "6" {
      Invoke-Helper "test_chat.ps1"
      Pause-Control
    }
    "7" {
      wsl -d Ubuntu-24.04 -- bash -lc "tail -n 120 /tmp/vllm-exaone.log 2>/dev/null || true"
      Pause-Control
    }
    "0" {
      break menu
    }
    default {
      Write-Host "Unknown selection: $choice"
      Pause-Control
    }
  }
}
