#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
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

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "ERROR: localhost:8080 is already in use. Stop that process first."
  exit 1
fi

echo "[ops-demo] Starting VM-side ArgoCD port-forward..."
vagrant ssh -c "cd /vagrant && ./scripts/vm/start-argocd-port-forward.sh"

echo "[ops-demo] Starting SSH tunnel localhost:8080 -> VM:8080"
echo "[ops-demo] Tunnel actief. Open: http://localhost:8080"
echo "[ops-demo] Stoppen met Ctrl+C."
exec vagrant ssh -- -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -L 8080:127.0.0.1:8080
