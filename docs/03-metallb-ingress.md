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

## Leeswijzer

> **Voor beginners (optioneel):**
> In deze oefening komen netwerkconcepten samen (LoadBalancer IP, Ingress, DNS-hostname).
> Lees de "Wat dit doet" blokken eerst rustig door; plak pas daarna de YAML.

---

## Achtergrond

In cloud-Kubernetes (EKS, GKE, AKS) regelt `type: LoadBalancer` automatisch een load balancer met een extern IP. Op bare
metal of lokale VMs doet niets dat — pods blijven onbereikbaar van buitenaf.

**MetalLB** lost dit op: hij luistert naar LoadBalancer-services en kent IPs toe uit een pool die jij definieert. In
L2-modus gebruikt hij ARP — jouw laptop vraagt "wie heeft 192.168.56.200?" en MetalLB antwoordt namens de VM.

**Ingress-Nginx** is één LoadBalancer-service die van MetalLB één IP krijgt. Al je apps delen dat IP — Nginx routeert op
basis van de `Host:` header.

**nip.io** is publieke wildcard-DNS: `iets.192.168.56.200.nip.io` resolved altijd naar `192.168.56.200`. Geen noodzaak
meer om je `/etc/hosts` aanpassen.

---

## Stappen

### 1. MetalLB installeren

Maak de volgende bestanden aan:

**`manifests/networking/metallb/values.yaml`**

> [!TIP]
> **Wat dit doet**
> - Dit is de Helm-values file voor MetalLB.
> - In deze workshop-VM kun je hem leeg laten; de standaard chart-values zijn genoeg.

```yaml
{}
```

**`manifests/networking/metallb/metallb-config.yaml`**

> [!TIP]
> **Wat dit doet**
> - `IPAddressPool` bepaalt uit welke range MetalLB IP's mag uitdelen.
> - `L2Advertisement` maakt die pool zichtbaar op je host-only netwerk via ARP.
> - Daardoor kan je laptop services op dat IP direct bereiken.

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

> [!TIP]
> **Wat dit doet**
> - Installeert MetalLB via ArgoCD als aparte `Application`.
> - De chart komt van de upstream Helm repo; jouw repo levert de values via `$values/...`.
> - `sync-wave: "1"` zorgt dat MetalLB eerst klaar is.
> - `ignoreDifferences` voorkomt bekende CRD `caBundle` drift door dynamische webhook certs.

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
  ignoreDifferences:
    - group: apiextensions.k8s.io
      kind: CustomResourceDefinition
      jsonPointers:
        - /spec/conversion/webhook/clientConfig/caBundle
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

> [!TIP]
> **Wat dit doet**
> - Past jouw IP-pool/L2-config toe als losse ArgoCD `Application`.
> - Die split houdt "installatie" en "runtime-config" van MetalLB uit elkaar.
> - `sync-wave: "2"` laat dit pas lopen nadat MetalLB zelf staat.

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

> [!TIP]
> **Wat dit doet**
> - Zet ingress-nginx neer met een `LoadBalancer` service.
> - Dat service-IP wordt vast op `192.168.56.200` gezet.
> - Zo kun je stabiele hostnames gebruiken met `nip.io`.

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

> [!TIP]
> **Wat dit doet**
> - Installeert ingress-nginx via ArgoCD.
> - Ook hier: chart upstream, values uit jouw repo.
> - `sync-wave: "3"` laat ingress pas starten nadat MetalLB + config klaar zijn.

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

> **HOST**
> ```bash
> git add apps/networking/ manifests/networking/
> git commit -m "feat: MetalLB + Ingress-Nginx"
> git push
> ```

Wacht tot beide applications Synced zijn, en controleer dan:

> **VM**
> ```bash
> kubectl get svc -n ingress-nginx
> # NAME                       TYPE           EXTERNAL-IP      PORT(S)
> # ingress-nginx-controller   LoadBalancer   192.168.56.200   80:xxx,443:xxx
> ```

Vanuit je laptop:

> **HOST**
> ```bash
> curl http://192.168.56.200
> # 404 van Nginx — klopt, nog geen Ingress-regel
> ```

> **Voor beginners (optioneel):**
> Deze `404` is hier juist positief:
> je bereikt de ingress-controller wel, maar er is nog geen Ingress-regel voor jouw app.

---

### 4. Ingress voor podinfo toevoegen

**`manifests/apps/podinfo/ingress.yaml`**

> [!TIP]
> **Wat dit doet**
> - Definieert de HTTP-route voor podinfo.
> - `ingressClassName: nginx` bindt deze Ingress aan ingress-nginx.
> - De hostnaam met `nip.io` wijst naar jouw MetalLB IP.

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

> **HOST**
> ```bash
> git add manifests/apps/podinfo/ingress.yaml
> git commit -m "feat: voeg podinfo Ingress toe"
> git push
> ```

Open vanuit je laptop: **http://podinfo.192.168.56.200.nip.io**

---

### 5. ArgoCD-ingress inschakelen

Pas `manifests/argocd/values.yaml` aan. Zoek het uitgecommentarieerde ingress-blok en verwijder de `#`-tekens:

> [!TIP]
> **Wat dit doet**
> - Schakelt ingress in voor de ArgoCD server zelf.
> - Daarna kun je ArgoCD via browser-URL gebruiken in plaats van port-forward.
> - De `hostname` moet matchen met het IP dat ingress-nginx exposeert.

```yaml
  ingress:
    enabled: true
    ingressClassName: nginx
    hostname: argocd.192.168.56.200.nip.io
    annotations:
      nginx.ingress.kubernetes.io/ssl-passthrough: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
```

> **HOST**
> ```bash
> git add manifests/argocd/values.yaml
> git commit -m "feat: schakel ArgoCD ingress in"
> git push
> ```

ArgoCD detecteert de wijziging, past zijn eigen Helm-release aan en maakt de Ingress aan.
Open: **http://argocd.192.168.56.200.nip.io**

---

## Extra (optioneel) — alleen bij control-plane taints

Als `metallb-speaker` pods `Pending` blijven en je node heeft een control-plane `NoSchedule` taint,
voeg dan deze toleration toe in `manifests/networking/metallb/values.yaml`:

```yaml
speaker:
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
```
> [!TIP]
> **Wat dit doet**
> - `tolerations` zijn alleen nodig als je cluster control-plane `NoSchedule` taints gebruikt.
>
> **Termen uitgelegd**
>- `speaker`: de MetalLB component die op nodes draait en op het netwerk "antwoordt" voor een toegewezen
>  LoadBalancer-IP (in L2-modus via ARP).
> - `tolerations`: een Kubernetes-mechanisme waarmee een pod toch op een node mag landen die een `taint` heeft.
>   Control-plane nodes zijn vaak getaint met `NoSchedule`; zonder toleration wordt de speaker daar niet ingepland.

Commit en push daarna opnieuw, zodat ArgoCD MetalLB met deze values heruitrolt.

---

## Verwacht resultaat

| URL                                  | App            |
|--------------------------------------|----------------|
| http://podinfo.192.168.56.200.nip.io | podinfo v6.6.2 |
| http://argocd.192.168.56.200.nip.io  | ArgoCD UI      |

Beide bereikbaar vanaf je laptop zonder port-forward.

---

## Probleemoplossing

| Symptoom                              | Oplossing                                                                                                          |
|---------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| `EXTERNAL-IP` blijft `<pending>`      | MetalLB is nog niet klaar — check `kubectl get pods -n metallb-system`                                             |
| curl naar 192.168.56.200 time-out     | VirtualBox host-only adapter niet geconfigureerd — zie vm-setup.md                                                 |
| nip.io resolvet niet                  | Tijdelijk DNS-probleem, probeer opnieuw of voeg toe aan `/etc/hosts`                                               |
| ArgoCD ingress geeft 502              | Wacht tot ArgoCD herstart na de values-wijziging                                                                   |
| MetalLB app blijft OutOfSync op CRD's | Voeg in `apps/networking/metallb.yaml` `ignoreDifferences` toe voor CRD `caBundle` drift (zie voorbeeld hierboven) |

---

## Volgende stap

In Oefening 04 bouw je een Tekton-pipeline die automatisch de image-tag in Git aanpast, pusht, en laat ArgoCD de update
uitrollen.
