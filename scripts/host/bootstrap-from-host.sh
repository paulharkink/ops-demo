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

log_file="$(mktemp)"
trap 'rm -f "${log_file}"' EXIT

echo "[ops-demo] Running bootstrap in VM..."
vagrant ssh -c "cd /vagrant && ./scripts/vm/bootstrap.sh" | tee "${log_file}"

password="$(sed -n 's/.*ArgoCD admin-wachtwoord: //p' "${log_file}" | tail -n 1 | tr -d '\r')"
if [[ -z "${password}" ]]; then
  password="$(vagrant ssh -c "export KUBECONFIG=/home/vagrant/.kube/config; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" 2>/dev/null | tr -d '\r')"
fi

echo ""
echo "[ops-demo] Bootstrap complete."
if [[ -n "${password}" ]]; then
  echo "[ops-demo] ArgoCD admin password: ${password}"
else
  echo "[ops-demo] Could not extract ArgoCD admin password automatically."
fi

echo ""
echo "Next step to open ArgoCD UI from host:"
echo "  ./scripts/host/argocd-ui-tunnel.sh"
echo "Then browse: http://localhost:8080"
