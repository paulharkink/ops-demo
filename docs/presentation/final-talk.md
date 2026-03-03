# Final Talk — GitOps in de praktijk

---

## 1. Wat we gebouwd hebben

### Architectuurdiagram

```
┌─────────────────────────────────────────────────────────┐
│  Jouw laptop                                            │
│                                                         │
│  Browser  ──────────────────────────────────────────►   │
│           podinfo.192.168.56.200.nip.io                 │
│           argocd.192.168.56.200.nip.io                  │
│           grafana.192.168.56.200.nip.io                 │
└────────────────────────┬────────────────────────────────┘
                         │ VirtualBox host-only
                         ▼ 192.168.56.200 (MetalLB)
┌─────────────────────────────────────────────────────────┐
│  VM: ops-demo (192.168.56.10)                           │
│                                                         │
│  ┌──────────────────┐  ┌───────────────────────────┐    │
│  │  Ingress-Nginx   │  │  ArgoCD                   │    │
│  │  (LB: .200)      │  │  kijkt naar deze Git repo │    │
│  └──────┬───────────┘  └───────────┬───────────────┘    │
│         │                          │ synct              │
│         ▼                          ▼                    │
│  ┌──────────────────┐  ┌───────────────────────────┐    │
│  │  podinfo         │  │  MetalLB                  │    │
│  │  (Deployment)    │  │  (geeft LAN IP's uit)     │    │
│  └──────────────────┘  └───────────────────────────┘    │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Tekton Pipeline                                 │   │
│  │  clone → validate → bump tag → git push          │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### De GitOps loop

1. Alles in de cluster staat als declaratie in deze Git repo
2. ArgoCD kijkt naar de repo en reconcilet de cluster naar die gewenste state
3. De Tekton pipeline wordt zelf ook door ArgoCD gedeployed, en pusht commits die ArgoCD daarna weer synct
4. De enige `kubectl apply` die je vandaag deed: bootstrap van ArgoCD + PipelineRun triggeren

### Stack recap

| Component             | Rol                         |
|-----------------------|-----------------------------|
| k3s                   | Single-binary Kubernetes    |
| ArgoCD                | GitOps engine (App-of-Apps) |
| MetalLB               | Bare-metal LoadBalancer     |
| Ingress-Nginx         | HTTP routing op hostname    |
| Tekton                | CI pipeline (in-cluster)    |
| podinfo               | Demo-applicatie             |
| kube-prometheus-stack | Observability (bonus)       |

---

## 2. Waarom GitOps in productie

### De oude manier: imperatieve deploys

> **VM**
> ```bash
> # Iemand draait dit op vrijdagmiddag
> kubectl set image deployment/api api=company/api:v2.3.1-hotfix
> # Geen review. Geen audit trail. Niemand weet wie dit om 16:47 deed.
> ```

### De GitOps manier

```
PR: "bump API naar v2.3.1-hotfix"
  → peer review
  → merge
  → ArgoCD synct
  → deploy gebeurt
  → Git commit IS de audit trail
```

### Belangrijkste voordelen

**Audit trail**: Elke clusterwijziging heeft een Git commit: wie, wat, wanneer, waarom.

**Drift detection**: Als iemand direct `kubectl apply` doet, ziet ArgoCD drift en kan het automatisch terugdraaien. De cluster convergeert altijd terug naar wat in Git staat.

**Disaster recovery**: Cluster weg? `vagrant up` + `./scripts/vm/bootstrap.sh` + `kubectl apply -f apps/root.yaml` en ArgoCD bouwt alles opnieuw op. Git is je backup.

**Samenwerking tussen teams**: Developers openen PR's voor deploys. Ops reviewt manifest-wijzigingen. Geen SSH-sleutels op productie nodig.

**Rollback**: `git revert <commit>` + `git push`. Geen speciale tooling nodig.

### Het App-of-Apps pattern

Eén root Application beheert alle andere Applications. Nieuwe service toevoegen = één YAML-file in `apps/` toevoegen. De root app pakt die automatisch op.

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

## 3. Wat is de volgende stap

### Secrets management

Vandaag: plain Kubernetes Secrets met GitHub PATs.  
In productie: **Vault + external-secrets-operator**

```
Vault (secret store)
  → external-secrets-operator haalt secrets op
  → maakt Kubernetes Secrets aan
  → ArgoCD synct de rest
```

### Multi-cluster met ApplicationSets

Vandaag: één cluster, één repo.  
In productie: 10 clusters, één repo.

```yaml
# ArgoCD ApplicationSet: deploy podinfo naar elke cluster uit de lijst
generators:
  - list:
      elements:
        - cluster: staging
        - cluster: prod-eu
        - cluster: prod-us
```

### Progressive delivery

Vandaag: rolling update (all-or-nothing).  
In productie: **Argo Rollouts** met canary of blue/green.

```
Nieuwe versie → 5% van traffic
  → metrics goed → 20% → 50% → 100%
  → metrics slecht → auto-rollback
```
