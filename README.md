# Kubernetes GitOps Workshop

A hands-on 2.5–4 hour workshop teaching real-world cluster operations using
ArgoCD, MetalLB, Ingress-Nginx, and Tekton — all on a local single-node k3s cluster.

---

## Quick start

### Requirements

- [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant 2.4.x](https://developer.hashicorp.com/vagrant/downloads)
- Git
- 12 GB RAM free on your laptop, ~15 GB disk

### 1. Start the VM

```bash
git clone https://github.com/innspire/ops-demo.git
cd ops-demo
vagrant up          # first run: ~10–15 min
vagrant ssh
cd /vagrant
```

See [docs/vm-setup.md](docs/vm-setup.md) for verification steps and troubleshooting.

### 2. Bootstrap ArgoCD

```bash
./scripts/bootstrap.sh
```

Then follow the exercises in order.

---

## Exercises

| # | Exercise | Guide | Type | Est. Time |
|---|----------|-------|------|-----------|
| 01 | Bootstrap ArgoCD | [docs/01-argocd-bootstrap.md](docs/01-argocd-bootstrap.md) | Core | 30 min |
| 02 | Deploy podinfo via GitOps | [docs/02-deploy-podinfo.md](docs/02-deploy-podinfo.md) | Core | 30 min |
| 03 | MetalLB + Ingress-Nginx | [docs/03-metallb-ingress.md](docs/03-metallb-ingress.md) | Core | 45 min |
| 04 | Tekton pipeline | [docs/04-tekton-pipeline.md](docs/04-tekton-pipeline.md) | Core | 45 min |
| 05 | App upgrade + reflection | [docs/05-app-upgrade.md](docs/05-app-upgrade.md) | Core | 15 min |
| 06 | Prometheus + Grafana | [docs/06-monitoring.md](docs/06-monitoring.md) | Bonus | 60 min |

**Beginners**: aim for Exercises 01–03 (~1h45m).
**Everyone else**: target 01–05 for the full core loop.

---

## Stack

| Component | Purpose | Version |
|-----------|---------|---------|
| k3s | Kubernetes | v1.31.4 |
| ArgoCD | GitOps engine | v2.13.x (chart 7.7.11) |
| MetalLB | Bare-metal LoadBalancer | v0.14.9 |
| Ingress-Nginx | HTTP routing | chart 4.12.0 |
| Tekton | CI pipeline | v0.65.1 |
| podinfo | Demo app | 6.6.2 → 6.7.0 |
| kube-prometheus-stack | Observability (bonus) | chart 68.4.4 |

---

## Solution branches

Stuck on an exercise? Each solution branch is cumulative — it contains the complete
working state up to and including that exercise.

```bash
# View a specific file without checking out the branch
git fetch origin
git show origin/solution/03-metallb-ingress:manifests/networking/metallb/metallb-config.yaml
```

| Branch | State |
|--------|-------|
| `solution/01-argocd-bootstrap` | ArgoCD running |
| `solution/02-deploy-podinfo` | podinfo synced via ArgoCD |
| `solution/03-metallb-ingress` | LAN access via MetalLB + Ingress |
| `solution/04-tekton-pipeline` | Full GitOps CI loop |
| `solution/05-app-upgrade` | podinfo at v6.7.0 |
| `solution/06-monitoring` | Prometheus + Grafana running |

---

## Network layout

```
Your laptop
    │
    │ 192.168.56.x (VirtualBox host-only)
    ▼
VM: 192.168.56.10
    │
    └── MetalLB pool: 192.168.56.200–192.168.56.220
            │
            └── 192.168.56.200  →  Ingress-Nginx
                    │
                    ├── podinfo.192.168.56.200.nip.io
                    ├── argocd.192.168.56.200.nip.io
                    └── grafana.192.168.56.200.nip.io  (bonus)
```
