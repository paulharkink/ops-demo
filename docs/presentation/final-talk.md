# Final Talk — GitOps in Practice

**Duration**: ~20 min + Q&A
**Format**: Slides or whiteboard; optional live demo

---

## 1. What We Built (7 min)

### Architecture diagram

```
┌─────────────────────────────────────────────────────────┐
│  Your Laptop                                            │
│                                                         │
│  Browser  ──────────────────────────────────────────►  │
│           podinfo.192.168.56.200.nip.io                 │
│           argocd.192.168.56.200.nip.io                  │
│           grafana.192.168.56.200.nip.io (bonus)         │
└────────────────────────┬────────────────────────────────┘
                         │ VirtualBox host-only
                         ▼ 192.168.56.200 (MetalLB)
┌─────────────────────────────────────────────────────────┐
│  VM: ops-demo (192.168.56.10)                           │
│                                                         │
│  ┌──────────────────┐  ┌───────────────────────────┐   │
│  │  Ingress-Nginx   │  │  ArgoCD                   │   │
│  │  (LB: .200)      │  │  watches this Git repo    │   │
│  └──────┬───────────┘  └───────────┬───────────────┘   │
│         │                          │ syncs              │
│         ▼                          ▼                    │
│  ┌──────────────────┐  ┌───────────────────────────┐   │
│  │  podinfo         │  │  MetalLB                  │   │
│  │  (Deployment)    │  │  (assigns LAN IPs)        │   │
│  └──────────────────┘  └───────────────────────────┘   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Tekton Pipeline                                 │   │
│  │  clone → validate → bump tag → git push          │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### The GitOps loop (narrate this)

1. Everything in the cluster is defined in **this Git repo**
2. ArgoCD watches the repo and reconciles the cluster to match
3. The Tekton pipeline is itself deployed by ArgoCD — and it pushes commits that ArgoCD then syncs
4. The only `kubectl apply` you ran today was: bootstrap ArgoCD + trigger PipelineRun

### Stack recap

| Component | Role |
|-----------|------|
| k3s | Single-binary Kubernetes |
| ArgoCD | GitOps engine (App-of-Apps) |
| MetalLB | Bare-metal LoadBalancer |
| Ingress-Nginx | HTTP routing by hostname |
| Tekton | CI pipeline (in-cluster) |
| podinfo | Demo application |
| kube-prometheus-stack | Observability (bonus) |

---

## 2. Why GitOps in Production (8 min)

### The old way: imperative deploys

```bash
# Someone runs this on a Friday afternoon
kubectl set image deployment/api api=company/api:v2.3.1-hotfix
# No review. No audit trail. No way to know who ran it at 16:47.
```

### The GitOps way

```
PR: "bump API to v2.3.1-hotfix"
  → peer review
  → merge
  → ArgoCD syncs
  → deploy happens
  → Git commit IS the audit trail
```

### Key benefits

**Audit trail**: Every cluster change has a Git commit — who, what, when, why.

**Drift detection**: If someone `kubectl apply`s directly, ArgoCD detects the drift and can auto-revert. The cluster always converges to what's in Git.

**Disaster recovery**: The cluster is destroyed? `vagrant up` + `./scripts/bootstrap.sh` + `kubectl apply -f apps/root.yaml` — and ArgoCD recreates everything. Git is the backup.

**Multi-team collaboration**: Developers open PRs to deploy. Ops reviews the manifest changes. No SSH keys to production.

**Rollback**: `git revert <commit>` + `git push`. No special tooling.

### The App-of-Apps pattern (brief)

One root Application manages all other Applications. Adding a new service = adding a single YAML file to `apps/`. The root app picks it up automatically.

```
apps/root.yaml  ──manages──►  apps/argocd.yaml
                              apps/apps/podinfo.yaml
                              apps/networking/metallb.yaml
                              apps/networking/ingress-nginx.yaml
                              apps/ci/tekton.yaml
                              apps/ci/pipeline.yaml
                              apps/monitoring/prometheus-grafana.yaml
```

---

## 3. What's Next (5 min)

### Secrets management

Today: plain Kubernetes Secrets with GitHub PATs.
Production: **Vault + external-secrets-operator**

```
Vault (secret store)
  → external-secrets-operator pulls secrets
  → creates Kubernetes Secrets
  → ArgoCD syncs everything else
```

### Multi-cluster with ApplicationSets

Today: one cluster, one repo.
Production: 10 clusters, one repo.

```yaml
# ArgoCD ApplicationSet: deploy podinfo to every cluster in a list
generators:
  - list:
      elements:
        - cluster: staging
        - cluster: prod-eu
        - cluster: prod-us
```

### Progressive delivery

Today: rolling update (all-or-nothing).
Production: **Argo Rollouts** with canary or blue/green strategies.

```
New version → 5% of traffic
  → metrics look good → 20% → 50% → 100%
  → metrics bad → auto-rollback
```

---

## Optional live demo (~5 min)

Make a one-line change to `manifests/apps/podinfo/deployment.yaml` (e.g. UI color),
push to GitHub, click **Refresh** in ArgoCD, and show the pod restart and new UI.

The audience has already done this — seeing it narrated makes the loop visceral.

---

## Q&A prompts (if the room is quiet)

- "How would you handle database migrations in a GitOps flow?"
- "What happens if two people push to Git at the same time?"
- "When is GitOps NOT the right tool?" (answer: local dev, scripts, one-off jobs)
- "How do you keep secrets out of Git at scale?"
