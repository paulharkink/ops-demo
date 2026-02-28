#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/argocd-port-forward.log"
PID_FILE="/tmp/argocd-port-forward.pid"

# Kill any process currently listening on VM localhost:8080.
# We intentionally target the listener port, not a command pattern.
if command -v lsof >/dev/null 2>&1; then
  pids="$(lsof -t -iTCP:8080 -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    kill ${pids} >/dev/null 2>&1 || true
    sleep 1
  fi
fi

nohup "${SCRIPT_DIR}/argocd-port-forward.sh" >"${LOG_FILE}" 2>&1 </dev/null &
echo $! >"${PID_FILE}"

sleep 1
if ! kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  echo "ERROR: failed to start VM-side ArgoCD port-forward." >&2
  tail -n 40 "${LOG_FILE}" >&2 || true
  exit 1
fi
