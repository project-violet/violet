$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResolvedScript = Join-Path $ScriptDir "start_vllm_exaone_wsl.sh"
$WslScript = $ResolvedScript -replace "\\", "/"

if ($WslScript -match "^([A-Za-z]):/(.*)$") {
  $Drive = $Matches[1].ToLowerInvariant()
  $Rest = $Matches[2]
  $WslScript = "/mnt/$Drive/$Rest"
}

wsl -d Ubuntu-24.04 -- bash "$WslScript" stop
