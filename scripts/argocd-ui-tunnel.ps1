Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$status = vagrant status --machine-readable | Out-String
if ($status -notmatch ',state,running') {
  Write-Host '[ops-demo] VM is not running; starting with vagrant up...'
  vagrant up
}

Write-Host '[ops-demo] Ensuring VM-side port-forward is running...'
vagrant ssh -c "export KUBECONFIG=/home/vagrant/.kube/config; pgrep -f 'kubectl -n argocd port-forward svc/argocd-server 8080:443' >/dev/null || nohup kubectl -n argocd port-forward svc/argocd-server 8080:443 >/tmp/argocd-port-forward.log 2>&1 &" | Out-Null

Write-Host '[ops-demo] Opening SSH tunnel localhost:8080 -> VM:8080'
Write-Host '[ops-demo] Keep this terminal open while using https://localhost:8080'
vagrant ssh -- -L 8080:127.0.0.1:8080
