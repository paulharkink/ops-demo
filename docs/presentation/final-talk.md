# Final Talk - GitOps in de praktijk

## 1. Wat we nu echt hebben staan

Vandaag hebben we niet "een demo" gebouwd, maar een complete GitOps-loop:

1. Git bevat de gewenste state.
2. ArgoCD reconcilet de cluster daarnaar.
3. Tekton wijzigt Git (image-tag bump), en ArgoCD pakt dat weer op.
4. Alles is reproduceerbaar op een nieuwe VM.

### Snelle architectuur

```
Laptop/browser
  -> argocd.192.168.56.200.nip.io
  -> podinfo.192.168.56.200.nip.io
  -> grafana.192.168.56.200.nip.io

VirtualBox host-only netwerk

VM (k3s)
  -> ingress-nginx + MetalLB
  -> ArgoCD (app-of-apps)
  -> Tekton (CI in-cluster)
  -> podinfo (demo workload)
  -> monitoring (bonus)
```

### Componenten in 1 regel

| Component             | Waarom die hier zit                          |
|-----------------------|----------------------------------------------|
| k3s                   | Lichtgewicht Kubernetes voor lokale labs     |
| ArgoCD                | GitOps controller                            |
| MetalLB               | LoadBalancer IP op bare metal/VM             |
| ingress-nginx         | HTTP routing op hostnames                    |
| Tekton                | Pipeline als Kubernetes resources            |
| podinfo               | Eenvoudige app om deploys zichtbaar te maken |
| kube-prometheus-stack | Metrics en dashboards                        |

## 2. Waarom dit productie-relevant is

### Zonder GitOps (klassieke drift)

```bash
kubectl set image deployment/api api=company/api:hotfix
```

Dat werkt snel, maar je verliest context: geen review, lastig auditbaar, foutgevoelig.

### Met GitOps

1. Wijziging gaat via commit/PR.
2. Review + merge.
3. ArgoCD sync.
4. Git geschiedenis is je audit trail en rollback-mechanisme.

Concreet voordeel:

- Traceerbaarheid: wie veranderde wat en waarom.
- Driftcontrole: handmatige clusterwijzigingen vallen op.
- Herstelbaarheid: cluster kwijt -> opnieuw opbouwen vanuit Git.
- Samenwerking: app- en platformwijzigingen via hetzelfde proces.

## 3. App-of-Apps in het kort

`apps/root.yaml` verwijst naar onderliggende Argo Applications.

Dat betekent: nieuwe capability toevoegen = nieuwe app-definitie committen.
Geen losse handmatige installatiestappen op de cluster.

## 4. Grenzen van deze workshop-opzet

Dit is een leeromgeving. In productie zou je strakker willen op o.a.:

- Secrets: geen PATs als plain K8s secrets in Git-workflow, maar Vault + ESO of vergelijkbaar.
- Security: PSA/namespace policies bewust hardenen i.p.v. versoepelen voor labs.
- Multi-cluster: ApplicationSets en promotieflow (dev -> staging -> prod).
- Delivery-strategie: canary/blue-green met meetbare rollback-criteria.

## 5. Wat je mee moet nemen

Als je 1 ding onthoudt:

"Het cluster is een runtime-kopie van wat in Git staat."

Niet andersom.

Dat principe maakt deployments voorspelbaar, bespreekbaar en herstelbaar.
