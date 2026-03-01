# Oefening 02 — podinfo deployen via GitOps

**Tijd**: ~30 minuten
**Doel**: Een echte applicatie deployen puur via Git — geen `kubectl apply`.

---


## Wat je leert

- Hoe je een ArgoCD Application toevoegt door één bestand te committen
- Hoe je de sync-status en health van een applicatie leest
- De GitOps-loop in de praktijk: commit → push → ArgoCD detecteert → cluster bijgewerkt

---

## Leeswijzer

> **Voor beginners (optioneel):**
> In deze oefening doe je bewust geen `kubectl apply` voor podinfo.
> Dat voelt in het begin onnatuurlijk, maar is precies het GitOps-principe: Git verandert, ArgoCD voert uit.

---

## Vereisten

Oefening 01 afgerond. ArgoCD draait en de root app is Synced.

---

## Achtergrond: wat is podinfo?

podinfo is een kleine Go-webapp van Stefan Prodan (ook de maker van Flux).
Hij wordt veel gebruikt in Kubernetes-demo's: toont zijn eigen versienummer,
heeft `/healthz` en `/readyz` endpoints, en ziet er prima uit in een browser.
Geen externe dependencies, geen secrets nodig.

---

## Stappen

### 1. De manifests aanmaken

Maak de volgende bestanden aan:

**`manifests/apps/podinfo/namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: podinfo
```

**`manifests/apps/podinfo/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
  namespace: podinfo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      containers:
        - name: podinfo
          image: ghcr.io/stefanprodan/podinfo:6.6.2
          ports:
            - containerPort: 9898
              name: http
          env:
            - name: PODINFO_UI_COLOR
              value: "#6C48C5"
          readinessProbe:
            httpGet:
              path: /readyz
              port: 9898
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
```

**`manifests/apps/podinfo/service.yaml`**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: podinfo
  namespace: podinfo
spec:
  selector:
    app: podinfo
  ports:
    - port: 80
      targetPort: 9898
      name: http
```

---

### 2. De ArgoCD Application aanmaken

**`apps/apps/podinfo.yaml`**

> **Voor beginners (optioneel):**
> Zie deze `Application` als een "pointer":
> hij zegt tegen ArgoCD *waar* de echte Kubernetes YAML staat (`manifests/apps/podinfo`) en *waar* die toegepast moet worden (namespace `podinfo`).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/apps/podinfo
  destination:
    server: https://kubernetes.default.svc
    namespace: podinfo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Vervang `JOUW_FORK_URL` door jouw fork-URL.

---

### 3. Committen en pushen

> **HOST**
> ```bash
> git add apps/apps/podinfo.yaml manifests/apps/podinfo/
> git commit -m "feat: deploy podinfo via GitOps"
> git push
> ```

Dit is de enige actie die nodig is om de applicatie te deployen.

> **Het GitOps-punt**: je hebt geen `kubectl apply` uitgevoerd voor podinfo.
> Je hebt een bestand gecommit, en ArgoCD regelt de rest.

---

### 4. Wachten tot het Synced is

> **VM**
> ```bash
> kubectl get application podinfo -n argocd -w
> ```

Wacht tot je `Synced` en `Healthy` ziet. Dan:

> **VM**
> ```bash
> kubectl get pods -n podinfo
> # NAME                     READY   STATUS    RESTARTS   AGE
> # podinfo-xxx-xxx          1/1     Running   0          30s
> ```

---

### 5. Controleer dat de app werkt

> **VM**
> ```bash
> kubectl port-forward svc/podinfo -n podinfo 9898:80
> ```

In een ander terminal (of via curl):

> **HOST**
> ```bash
> curl http://localhost:9898
> # {"hostname":"podinfo-xxx","version":"6.6.2", ...}
> ```

Versie `6.6.2` — dat klopt met de image-tag in `deployment.yaml`.

---

### 6. Maak een GitOps-wijziging

Pas de UI-kleur aan om te bewijzen dat de loop werkt.

Verander in `manifests/apps/podinfo/deployment.yaml`:

```yaml
value: "#6C48C5"
```

naar bijv.:

```yaml
value: "#2ecc71"
```

Commit en push:

> **HOST**
> ```bash
> git add manifests/apps/podinfo/deployment.yaml
> git commit -m "chore: verander podinfo UI-kleur"
> git push
> ```

Binnen ~3 minuten (standaard poll-interval van ArgoCD) herstart de pod
en zie je de nieuwe kleur. Je kunt ook op **Refresh** klikken in de UI
voor direct effect.

---

## Verwacht resultaat

```
NAME      SYNC STATUS   HEALTH STATUS
podinfo   Synced        Healthy
```

---

## Probleemoplossing

| Symptoom                         | Oplossing                                                     |
|----------------------------------|---------------------------------------------------------------|
| Application blijft "Progressing" | `kubectl describe pod -n podinfo` — waarschijnlijk image pull |
| ArgoCD toont OutOfSync na push   | Klik **Refresh** of wacht 3 minuten                           |

---

## Volgende stap

podinfo draait maar is alleen bereikbaar via port-forward.
In Oefening 03 stel je MetalLB en Ingress-Nginx in zodat je de app
vanuit je browser op je laptop kunt bereiken, zonder port-forward.
