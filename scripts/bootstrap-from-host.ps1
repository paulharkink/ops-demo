Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Ensure-VagrantRunning {
  $status = vagrant status --machine-readable | Out-String
  if ($status -notmatch ',state,running') {
    Write-Host '[ops-demo] VM is not running; starting with vagrant up...'
    vagrant up
  }
}

Write-Host '[ops-demo] Checking VM status...'
Ensure-VagrantRunning

Write-Host '[ops-demo] Running bootstrap in VM...'
$output = vagrant ssh -c "cd /vagrant && ./scripts/bootstrap.sh" | Out-String
Write-Host $output

$password = $null
if ($output -match 'ArgoCD admin-wachtwoord:\s*(\S+)') {
  $password = $Matches[1]
}

if (-not $password) {
  $fallback = vagrant ssh -c "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" | Out-String
  $password = $fallback.Trim()
}

Write-Host ''
Write-Host '[ops-demo] Bootstrap complete.'
if ($password) {
  Write-Host "[ops-demo] ArgoCD admin password: $password"
} else {
  Write-Host '[ops-demo] Could not extract ArgoCD admin password automatically.'
}

Write-Host ''
Write-Host 'Next step to open ArgoCD UI from host:'
Write-Host '  ./scripts/argocd-ui-tunnel.ps1'
Write-Host 'Then browse: https://localhost:8080'
