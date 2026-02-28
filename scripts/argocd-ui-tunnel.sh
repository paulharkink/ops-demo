#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

command -v vagrant >/dev/null 2>&1 || {
  echo "ERROR: required command not found: vagrant" >&2
  exit 1
}

echo "[ops-demo] Checking VM status..."
if ! vagrant status --machine-readable | rg -q ',state,running'; then
  echo "[ops-demo] VM is not running; starting with vagrant up..."
  vagrant up
fi

echo "[ops-demo] Ensuring VM-side port-forward is running..."
vagrant ssh -c "pgrep -f 'kubectl -n argocd port-forward svc/argocd-server 8080:443' >/dev/null || nohup kubectl -n argocd port-forward svc/argocd-server 8080:443 >/tmp/argocd-port-forward.log 2>&1 &" >/dev/null

echo "[ops-demo] Opening SSH tunnel localhost:8080 -> VM:8080"
echo "[ops-demo] Keep this terminal open while using https://localhost:8080"
vagrant ssh -- -L 8080:127.0.0.1:8080
