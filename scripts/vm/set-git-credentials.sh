#!/usr/bin/env bash
# set-git-credentials.sh — Create the git-credentials Secret for the Tekton pipeline.
#
# Usage:
#   ./scripts/vm/set-git-credentials.sh <github-username> <github-pat>
#
# The PAT needs: repo (read + write) scope.
# The Secret is NOT stored in git — it lives only in the cluster.
#
# Run this once before triggering the PipelineRun.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <github-username> <github-personal-access-token>"
  exit 1
fi

GITHUB_USER="$1"
GITHUB_PAT="$2"
NAMESPACE="tekton-pipelines"
PIPELINERUN_REL="manifests/ci/pipeline/pipelinerun.yaml"
if [[ -f "${PIPELINERUN_REL}" ]]; then
  PIPELINERUN_PATH="${PIPELINERUN_REL}"
elif [[ -f "/vagrant/${PIPELINERUN_REL}" ]]; then
  PIPELINERUN_PATH="/vagrant/${PIPELINERUN_REL}"
else
  # Fallback if workshop repo is in a custom location.
  PIPELINERUN_PATH="${PIPELINERUN_REL}"
fi

echo "→ Creating git-credentials Secret in namespace ${NAMESPACE}"

kubectl create secret generic git-credentials \
  --namespace "${NAMESPACE}" \
  --from-literal=username="${GITHUB_USER}" \
  --from-literal=password="${GITHUB_PAT}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secret created. The pipeline is ready to run."
echo ""
echo "  Trigger the pipeline:"
echo "    kubectl apply -f ${PIPELINERUN_PATH}"
echo ""
echo "  Watch progress:"
echo "    kubectl get pipelinerun -n tekton-pipelines -w"
echo "    # or use: tkn pipelinerun logs -f -n tekton-pipelines bump-podinfo-to-670"
