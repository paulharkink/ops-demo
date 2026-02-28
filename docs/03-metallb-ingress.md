# Oefening 03 — MetalLB + Ingress-Nginx

**Tijd**: ~45 minuten
**Doel**: podinfo en de ArgoCD UI bereikbaar maken op een echt LAN-IP — vanuit je browser op je laptop, zonder
port-forward.

---

## Wat je leert

- Waarom je MetalLB nodig hebt op een bare-metal of lokaal Kubernetes-cluster
- Hoe een LoadBalancer-service een echt IP krijgt via L2 ARP
- Hoe Ingress-Nginx HTTP-verkeer routeert op basis van hostname
- nip.io: gratis wildcard-DNS voor lokale development

---

## Achtergrond

In cloud-Kubernetes (EKS, GKE, AKS) regelt `type: LoadBalancer` automatisch een load balancer met een extern IP. Op bare
metal of lokale VMs doet niets dat — pods blijven onbereikbaar van buitenaf.

**MetalLB** lost dit op: hij luistert naar LoadBalancer-services en kent IPs toe uit een pool die jij definieert. In
L2-modus gebruikt hij ARP — jouw laptop vraagt "wie heeft 192.168.56.200?" en MetalLB antwoordt namens de VM.

**Ingress-Nginx** is één LoadBalancer-service die van MetalLB één IP krijgt. Al je apps delen dat IP — Nginx routeert op
basis van de `Host:` header.

**nip.io** is publieke wildcard-DNS: `iets.192.168.56.200.nip.io` resolvet altijd naar `192.168.56.200`. Geen
`/etc/hosts` aanpassen.

---

## Stappen

### 1. MetalLB installeren

Maak de volgende bestanden aan:

**`manifests/networking/metallb/values.yaml`**

```yaml
speaker:
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
```

**`manifests/networking/metallb/metallb-config.yaml`**

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: workshop-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.56.200-192.168.56.220
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: workshop-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - workshop-pool
```

**`apps/networking/metallb.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metallb
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: workshop
  sources:
    - repoURL: https://metallb.github.io/metallb
      chart: metallb
      targetRevision: "0.14.9"
      helm:
        valueFiles:
          - $values/manifests/networking/metallb/values.yaml
    - repoURL: JOUW_FORK_URL
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: metallb-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

**`apps/networking/metallb-config.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: metallb-config
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/networking/metallb
    directory:
      include: "metallb-config.yaml"
  destination:
    server: https://kubernetes.default.svc
    namespace: metallb-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 2. Ingress-Nginx installeren

**`manifests/networking/ingress-nginx/values.yaml`**

```yaml
controller:
  ingressClassResource:
    name: nginx
    default: true
  service:
    type: LoadBalancer
    loadBalancerIP: "192.168.56.200"
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
```

**`apps/networking/ingress-nginx.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ingress-nginx
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: workshop
  sources:
    - repoURL: https://kubernetes.github.io/ingress-nginx
      chart: ingress-nginx
      targetRevision: "4.12.0"
      helm:
        valueFiles:
          - $values/manifests/networking/ingress-nginx/values.yaml
    - repoURL: JOUW_FORK_URL
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

### 3. Alles committen en pushen

```bash
git add apps/networking/ manifests/networking/
git commit -m "feat: MetalLB + Ingress-Nginx"
git push
```

Wacht tot beide applications Synced zijn, en controleer dan:

```bash
kubectl get svc -n ingress-nginx
# NAME                       TYPE           EXTERNAL-IP      PORT(S)
# ingress-nginx-controller   LoadBalancer   192.168.56.200   80:xxx,443:xxx
```

Vanuit je laptop:

```bash
curl http://192.168.56.200
# 404 van Nginx — klopt, nog geen Ingress-regel
```

---

### 4. Ingress voor podinfo toevoegen

**`manifests/apps/podinfo/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: podinfo
spec:
  ingressClassName: nginx
  rules:
    - host: podinfo.192.168.56.200.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: podinfo
                port:
                  name: http
```

```bash
git add manifests/apps/podinfo/ingress.yaml
git commit -m "feat: voeg podinfo Ingress toe"
git push
```

Open vanuit je laptop: **http://podinfo.192.168.56.200.nip.io**

---

### 5. ArgoCD-ingress inschakelen

Pas `manifests/argocd/values.yaml` aan. Zoek het uitgecommentarieerde ingress-blok en verwijder de `#`-tekens:

```yaml
  ingress:
    enabled: true
    ingressClassName: nginx
    hostname: argocd.192.168.56.200.nip.io
    annotations:
      nginx.ingress.kubernetes.io/ssl-passthrough: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
```

```bash
git add manifests/argocd/values.yaml
git commit -m "feat: schakel ArgoCD ingress in"
git push
```

ArgoCD detecteert de wijziging, past zijn eigen Helm-release aan en maakt de Ingress aan.
Open: **http://argocd.192.168.56.200.nip.io**

---

## Verwacht resultaat

| URL                                  | App            |
|--------------------------------------|----------------|
| http://podinfo.192.168.56.200.nip.io | podinfo v6.6.2 |
| http://argocd.192.168.56.200.nip.io  | ArgoCD UI      |

Beide bereikbaar vanaf je laptop zonder port-forward.

---

## Probleemoplossing

| Symptoom                          | Oplossing                                                              |
|-----------------------------------|------------------------------------------------------------------------|
| `EXTERNAL-IP` blijft `<pending>`  | MetalLB is nog niet klaar — check `kubectl get pods -n metallb-system` |
| curl naar 192.168.56.200 time-out | VirtualBox host-only adapter niet geconfigureerd — zie vm-setup.md     |
| nip.io resolvet niet              | Tijdelijk DNS-probleem, probeer opnieuw of voeg toe aan `/etc/hosts`   |
| ArgoCD ingress geeft 502          | Wacht tot ArgoCD herstart na de values-wijziging                       |

---

## Volgende stap

In Oefening 04 bouw je een Tekton-pipeline die automatisch de image-tag in Git aanpast, pusht, en laat ArgoCD de update
uitrollen.
