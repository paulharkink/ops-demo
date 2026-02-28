Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $RepoRoot

$status = vagrant status --machine-readable | Out-String
if ($status -notmatch ',state,running') {
  Write-Host '[ops-demo] VM is not running; starting with vagrant up...'
  vagrant up
}

$check = netstat -ano | Select-String ':8080'
if ($check) {
  throw 'localhost:8080 is already in use. Stop that process first.'
}

Write-Host '[ops-demo] Starting VM-side ArgoCD port-forward...'
vagrant ssh -c "cd /vagrant && ./scripts/vm/start-argocd-port-forward.sh" | Out-Null

Write-Host '[ops-demo] Starting SSH tunnel localhost:8080 -> VM:8080'
Write-Host '[ops-demo] Tunnel actief. Open: http://localhost:8080'
Write-Host '[ops-demo] Stoppen met Ctrl+C.'
vagrant ssh -- -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 8080:127.0.0.1:8080
