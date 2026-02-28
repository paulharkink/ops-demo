#!/usr/bin/env bash
# bootstrap.sh — Install ArgoCD via Helm and apply the root App-of-Apps
# Run this once inside the VM after `vagrant up`.
#
# Usage:
#   cd /vagrant
#   ./scripts/bootstrap.sh
#
# What it does:
#   1. Creates the argocd namespace
#   2. Installs ArgoCD via Helm using manifests/argocd/values.yaml
#   3. Waits for ArgoCD server to be ready
#   4. Applies apps/root.yaml  (App-of-Apps entry point)
#   5. Prints the initial admin password and a port-forward hint

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_CHART_VERSION="7.7.11"   # ArgoCD chart 7.x → ArgoCD v2.13.x
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "══════════════════════════════════════════════"
echo "  ops-demo Bootstrap"
echo "══════════════════════════════════════════════"

# ── 1. Namespace ──────────────────────────────────────────────────────────────
echo "→ Creating namespace: ${ARGOCD_NAMESPACE}"
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ── 2. Helm install ArgoCD ────────────────────────────────────────────────────
echo "→ Adding Argo Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

echo "→ Installing ArgoCD (chart ${ARGOCD_CHART_VERSION})"
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --version "${ARGOCD_CHART_VERSION}" \
  --values "${REPO_ROOT}/manifests/argocd/values.yaml" \
  --wait \
  --timeout 5m

# ── 3. Apply root App-of-Apps ─────────────────────────────────────────────────
echo "→ Applying root App-of-Apps"
kubectl apply -f "${REPO_ROOT}/apps/project.yaml"
kubectl apply -f "${REPO_ROOT}/apps/root.yaml"

# ── 4. Print admin password ───────────────────────────────────────────────────
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "══════════════════════════════════════════════"
echo "  Bootstrap complete!"
echo ""
echo "  ArgoCD admin password: ${ARGOCD_PASSWORD}"
echo ""
echo "  To open the ArgoCD UI, run in a new terminal:"
echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then open: https://localhost:8080"
echo "  Login: admin / ${ARGOCD_PASSWORD}"
echo ""
echo "  After Exercise 03, ArgoCD will also be reachable at:"
echo "    https://argocd.192.168.56.200.nip.io"
echo "══════════════════════════════════════════════"
