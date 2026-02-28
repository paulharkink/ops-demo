# Oefening 05 — App upgrade en reflectie

**Tijd**: ~15 minuten
**Doel**: Terugkijken op wat je gebouwd hebt en de GitOps-loop nog een keer doorlopen.

---


## Wat je gebouwd hebt

```
Git-repo (single source of truth)
      │
      │  ArgoCD pollt elke 3 minuten
      ▼
ArgoCD (GitOps engine)
      │  detecteert drift tussen Git en cluster
      ▼
Kubernetes cluster
      │  MetalLB kent LAN-IP toe aan Ingress-Nginx
      ▼
Ingress-Nginx (routeert op hostname)
      │
      ├─► podinfo.192.168.56.200.nip.io  →  podinfo Deployment
      └─► argocd.192.168.56.200.nip.io   →  ArgoCD UI
```

En een CI-pipeline die de loop sluit:

```
Tekton PipelineRun
      │
      ├─ valideer manifests
      ├─ pas image-tag aan in deployment.yaml
      └─ git push
            │
            ▼
      ArgoCD detecteert commit → synchroniseert → rolling update
```

---

## Waarom is dit "GitOps"?

1. **Git is de enige bron van waarheid** — de cluster-staat is altijd afgeleid van deze repo
2. **Geen handmatige `kubectl apply`** — alle cluster-wijzigingen gaan via Git-commits
3. **Drift detection** — iemand past iets handmatig aan in de cluster? ArgoCD draait het terug
4. **Auditlog** — elke cluster-wijziging heeft een bijbehorende Git-commit
5. **Rollback = `git revert`** — geen speciale tooling nodig

---

## Probeer het: handmatige downgrade

Als de pipeline podinfo al naar `6.7.0` heeft gebracht, probeer dan een handmatige downgrade:

> **HOST**
> ```bash
> # Pas de image-tag terug aan naar 6.6.2
> vim manifests/apps/podinfo/deployment.yaml
>
> git add manifests/apps/podinfo/deployment.yaml
> git commit -m "chore: downgrade podinfo naar 6.6.2"
> git push
> ```

Kijk hoe ArgoCD synchroniseert, en verifieer:

> **HOST**
> ```bash
> curl http://podinfo.192.168.56.200.nip.io | jq .version
> # "6.6.2"
> ```

En upgrade dan weer via de pipeline:

> **VM**
> ```bash
> kubectl delete pipelinerun bump-podinfo-to-670 -n tekton-pipelines
> kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml
> ```

---

## Probeer het: drift detection

ArgoCD heeft `selfHeal: true` — hij draait handmatige cluster-wijzigingen automatisch terug.

> **VM**
> ```bash
> # Wijzig de image-tag direct in de cluster (buiten Git om)
> kubectl set image deployment/podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.5.0 -n podinfo
> ```

Kijk in de ArgoCD UI — binnen seconden gaat de podinfo-app op **OutOfSync**, en daarna zet ArgoCD hem terug naar wat er
in Git staat.

---

## Samenvatting

| Component     | Rol              | Hoe gedeployed |
|---------------|------------------|----------------|
| k3s           | Kubernetes       | Vagrantfile    |
| ArgoCD        | GitOps engine    | bootstrap.sh   |
| MetalLB       | LoadBalancer IPs | ArgoCD         |
| Ingress-Nginx | HTTP-routing     | ArgoCD         |
| podinfo       | Demo-applicatie  | ArgoCD         |
| Tekton        | CI-pipeline      | ArgoCD         |

---

## Volgende stap

Als je nog tijd hebt: **Oefening 06 (bonus)** — Prometheus + Grafana deployen en cluster-metrics bekijken in een live
dashboard.

Anders: sluit af met de **presentatie** over GitOps in productie.
