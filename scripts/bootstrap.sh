#!/usr/bin/env bash
# bootstrap.sh — Installeer ArgoCD via Helm en genereer de root App-of-Apps
# Eénmalig uitvoeren in de VM na `vagrant up`.
#
# Gebruik:
#   cd /vagrant
#   ./scripts/bootstrap.sh
#
# Wat het doet:
#   1. Detecteert de URL van jouw fork op basis van de git remote
#   2. Maakt de argocd namespace aan
#   3. Installeert ArgoCD via Helm (manifests/argocd/values.yaml)
#   4. Wacht tot ArgoCD klaar is
#   5. Past apps/project.yaml toe
#   6. Genereert apps/root.yaml met jouw fork-URL en past het toe
#   7. Print het admin-wachtwoord en een port-forward hint

set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_CHART_VERSION="7.7.11"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_NODE_NAME="ops-demo"
EXPECTED_HOST_ONLY_IP="$(awk -F'"' '/^HOST_ONLY_IP = "/ {print $2; exit}' "${REPO_ROOT}/Vagrantfile" 2>/dev/null || true)"
EXPECTED_HOST_ONLY_IP="${EXPECTED_HOST_ONLY_IP:-192.168.56.10}"
EXPECTED_API_SERVER="https://${EXPECTED_HOST_ONLY_IP}:6443"

die() {
  echo "FOUT: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "verplichte tool ontbreekt: $1"
}

echo "══════════════════════════════════════════════"
echo "  ops-demo Bootstrap"
echo "══════════════════════════════════════════════"

# ── Preflight checks ──────────────────────────────────────────────────────────
require_cmd git
require_cmd kubectl
require_cmd helm

# vagrant ssh -c can inherit host KUBECONFIG; force VM kubeconfig for safety.
if [[ -f /home/vagrant/.kube/config ]]; then
  export KUBECONFIG=/home/vagrant/.kube/config
fi

if ! kubectl get nodes >/dev/null 2>&1; then
  die "kubectl kan het cluster niet bereiken. Log in op de VM met 'vagrant ssh' en run het script vanaf /vagrant."
fi

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
CURRENT_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
if [[ "${CURRENT_SERVER}" != "${EXPECTED_API_SERVER}" ]]; then
  die "kubectl wijst naar '${CURRENT_SERVER:-onbekend}', verwacht '${EXPECTED_API_SERVER}'. Controleer je context eerst (huidige context: ${CURRENT_CONTEXT:-onbekend})."
fi

if ! kubectl get node "${EXPECTED_NODE_NAME}" -o name >/dev/null 2>&1; then
  die "verwachte node '${EXPECTED_NODE_NAME}' niet gevonden in huidige cluster. Stop om deploy naar de verkeerde cluster te voorkomen."
fi

if [[ "${CURRENT_CONTEXT}" != "ops-demo" ]]; then
  echo "WAARSCHUWING: huidige context is '${CURRENT_CONTEXT:-onbekend}', verwacht 'ops-demo'."
  echo "             Cluster-checks zijn wel geslaagd; je kunt doorgaan."
fi

if [[ "${PWD}" != /vagrant* ]]; then
  echo "WAARSCHUWING: je staat niet in /vagrant. Aanbevolen: 'cd /vagrant' voor je dit script draait."
fi

# ── 1. Detecteer fork URL ─────────────────────────────────────────────────────
REMOTE_URL=$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || echo "")
if [[ -z "${REMOTE_URL}" ]]; then
  echo "FOUT: geen git remote 'origin' gevonden."
  echo "      Clone de repo eerst via: git clone https://github.com/JOUW_USERNAME/ops-demo.git"
  exit 1
fi

# Converteer SSH naar HTTPS als nodig (git@github.com:user/repo.git → https://...)
if [[ "${REMOTE_URL}" == git@* ]]; then
  REPO_URL=$(echo "${REMOTE_URL}" | sed 's|git@github.com:|https://github.com/|')
else
  REPO_URL="${REMOTE_URL}"
fi
# Zorg dat de URL eindigt op .git
[[ "${REPO_URL}" == *.git ]] || REPO_URL="${REPO_URL}.git"

echo "→ Fork URL gedetecteerd: ${REPO_URL}"

# ── 2. Namespace ──────────────────────────────────────────────────────────────
echo "→ Namespace aanmaken: ${ARGOCD_NAMESPACE}"
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ── 3. Helm install ArgoCD ────────────────────────────────────────────────────
echo "→ Argo Helm-repo toevoegen"
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo

echo "→ ArgoCD installeren (chart ${ARGOCD_CHART_VERSION})"
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --version "${ARGOCD_CHART_VERSION}" \
  --values "${REPO_ROOT}/manifests/argocd/values.yaml" \
  --wait \
  --timeout 5m

# ── 4. AppProject toepassen ───────────────────────────────────────────────────
echo "→ AppProject 'workshop' aanmaken"
kubectl apply -f "${REPO_ROOT}/apps/project.yaml"

# ── 5. Genereer en pas apps/root.yaml toe ─────────────────────────────────────
echo "→ apps/root.yaml genereren voor ${REPO_URL}"
mkdir -p "${REPO_ROOT}/apps"
cat > "${REPO_ROOT}/apps/root.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: workshop
  source:
    repoURL: ${REPO_URL}
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

kubectl apply -f "${REPO_ROOT}/apps/root.yaml"

# ── 6. Print admin-wachtwoord ─────────────────────────────────────────────────
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "══════════════════════════════════════════════"
echo "  Bootstrap geslaagd!"
echo ""
echo "  ArgoCD admin-wachtwoord: ${ARGOCD_PASSWORD}"
echo ""
if [[ -n "${SSH_CONNECTION:-}" ]]; then
  echo "  Je draait via SSH (headless VM). Gebruik deze flow:"
  echo "    1) Op je laptop: vagrant ssh -- -L 8080:127.0.0.1:8080"
  echo "    2) In die VM-shell: kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "    3) Open op je laptop: https://localhost:8080  (login: admin / ${ARGOCD_PASSWORD})"
else
  echo "  Open de ArgoCD UI — voer dit uit in een nieuw terminal:"
  echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "  Dan: https://localhost:8080  (login: admin / ${ARGOCD_PASSWORD})"
fi
echo ""
echo "  apps/root.yaml is aangemaakt met jouw fork-URL."
echo "  Volgende stap (Oefening 01):"
echo "    git add apps/root.yaml && git commit -m 'feat: add root app' && git push"
echo "══════════════════════════════════════════════"
