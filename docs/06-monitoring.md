# Oefening 06 (Bonus) — Prometheus + Grafana

**Tijd**: ~60 minuten
**Doel**: Een volledige observability-stack deployen via ArgoCD en cluster- en applicatiemetrics bekijken in Grafana.

---


## Wat je leert

- Hoe je een complexe multi-component stack (kube-prometheus-stack) puur via GitOps deployet
- Hoe Prometheus metrics scrapt van Kubernetes en applicaties
- Navigeren door Grafana-dashboards voor cluster- en pod-metrics

---

## Vereisten

Oefeningen 01–03 afgerond. Ingress-Nginx draait en nip.io-URLs zijn bereikbaar vanaf je laptop.

> De monitoring-stack gebruikt extra ~700 MB geheugen. Op een 8 GB VM werkt het, maar kan wat traag aanvoelen.
> Als het te zwaar wordt, kun je `alertmanager` uitschakelen in de values.

---

## Stappen

### 1. Monitoring-Application aanmaken

**`manifests/monitoring/values.yaml`**

```yaml
grafana:
  adminPassword: workshop123
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.192.168.56.200.nip.io
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
    podMonitorSelectorNilUsesHelmValues: false
    serviceMonitorSelectorNilUsesHelmValues: false
    retention: 6h
    retentionSize: "1GB"
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: [ ReadWriteOnce ]
          resources:
            requests:
              storage: 2Gi

alertmanager:
  enabled: false

kubeStateMetrics:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi

nodeExporter:
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
```

**`apps/monitoring/prometheus-grafana.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-grafana
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: workshop
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: "68.4.4"
      helm:
        valueFiles:
          - $values/manifests/monitoring/values.yaml
    - repoURL: JOUW_FORK_URL
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

> **HOST**
> ```bash
> git add apps/monitoring/ manifests/monitoring/
> git commit -m "feat: Prometheus + Grafana via kube-prometheus-stack"
> git push
> ```

De initiële sync duurt 5–8 minuten — de chart is groot en installeert veel CRDs.

---

### 2. Wachten tot de stack klaar is

> **VM**
> ```bash
> kubectl get pods -n monitoring -w
> ```

Zodra alles Running is:

> **VM**
> ```bash
> kubectl get ingress -n monitoring
> # NAME      HOSTS                              ADDRESS
> # grafana   grafana.192.168.56.200.nip.io      192.168.56.200
> ```

---

### 3. Grafana openen

Vanuit je laptop: **http://grafana.192.168.56.200.nip.io**

Login: `admin` / `workshop123`

---

### 4. Dashboards verkennen

kube-prometheus-stack levert kant-en-klare dashboards mee. In de Grafana-sidebar: **Dashboards → Browse**.

Interessant voor deze workshop:

| Dashboard                                         | Wat je ziet                                      |
|---------------------------------------------------|--------------------------------------------------|
| Kubernetes / Compute Resources / Namespace (Pods) | CPU + geheugen per pod in de `podinfo` namespace |
| Kubernetes / Compute Resources / Node (Pods)      | Overzicht op node-niveau                         |
| Node Exporter / Full                              | VM-niveau: CPU, geheugen, schijf, netwerk        |

---

### 5. Load genereren op podinfo

> **VM**
> ```bash
> # In de VM
> while true; do curl -s http://podinfo.192.168.56.200.nip.io > /dev/null; sleep 0.2; done
> ```

Open in Grafana: **Kubernetes / Compute Resources / Namespace (Pods)** → namespace `podinfo`.
Je ziet het CPU-gebruik stijgen.

---

### 6. GitOps ook hier

Probeer het Grafana-wachtwoord aan te passen:

> **HOST**
> ```bash
> vim manifests/monitoring/values.yaml
> # Verander: adminPassword: workshop123
> # Naar:     adminPassword: nieuwwachtwoord
>
> git add manifests/monitoring/values.yaml
> git commit -m "chore: pas Grafana-wachtwoord aan"
> git push
> ```

ArgoCD synchroniseert de Helm-release en Grafana herstart. Log daarna in met het nieuwe wachtwoord.

---

## Probleemoplossing

| Symptoom                | Oplossing                                                                       |
|-------------------------|---------------------------------------------------------------------------------|
| Pods in Pending         | VM heeft te weinig geheugen — `kubectl describe pod` voor details               |
| Grafana 502 van Nginx   | Pod is nog niet klaar, even wachten                                             |
| Geen data in dashboards | Prometheus heeft ~2 minuten nodig voor de eerste scrape                         |
| CRD-conflict bij sync   | Eerste sync installeert CRDs, tweede sync past resources toe — opnieuw proberen |
