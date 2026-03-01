# Oefening 03b (Bonus) — Cloudflare Tunnel voor webhooks

**Tijd**: ~30–45 minuten
**Doel**: Je lokale workshop-cluster vanaf internet bereikbaar maken voor inkomende webhooks (bijv. GitHub -> Tekton).

---

## Wat je leert

- Waarom host-only networking (`192.168.56.x`) niet direct bereikbaar is vanaf internet
- Hoe Cloudflare Tunnel verkeer van internet veilig naar een interne Kubernetes-service brengt
- Hoe je dit later gebruikt in Oefening 04 voor echte GitHub webhooks

---

## Leeswijzer

> **Voor beginners (optioneel):**
> Zie Cloudflare Tunnel als een "uitgaande connector":
> een proces in jouw omgeving belt zelf uit naar Cloudflare.
> Daarna kan Cloudflare inkomend verkeer over die bestaande verbinding terugsturen.
> Je hoeft dus geen poorten op je laptop/router open te zetten.

---

## Vereisten

- Oefening 03 afgerond (Ingress-Nginx werkt)
- Een Cloudflare account
- Je repo/fork op `main`

Optioneel:
- Eigen domein in Cloudflare (alleen nodig voor **Route B** hieronder)

---

## Kies je route

Je hebt twee manieren:

- **Route A (geen domein nodig)**: snelle, tijdelijke `*.trycloudflare.com` URL
- **Route B (met eigen domein, aanbevolen)**: stabiele URL zoals `tekton-webhook.<jouw-domein>`

Wanneer welke?

- Gebruik **Route A** als je snel wilt testen zonder domein.
- Gebruik **Route B** als je een blijvende endpoint wilt (handig voor workshop-herhaling en stabiele GitHub webhook).

---

## Route A — Zonder eigen domein (tijdelijke test-URL)

### A1. Start een quick tunnel vanaf je host

> **HOST**
> ```bash
> cloudflared tunnel --url http://192.168.56.200 --http-host-header tekton-webhook.192.168.56.200.nip.io
> ```

Je krijgt output met een publieke URL, bijvoorbeeld:

```text
https://random-words.trycloudflare.com
```

Laat dit proces open staan.

> **Voor beginners (optioneel):**
> `--http-host-header` is belangrijk: daarmee blijft Ingress-Nginx de juiste route kiezen voor de Tekton listener.

### A2. Gebruik deze URL in GitHub webhook

In GitHub:

- **Settings -> Webhooks -> Add webhook**
- Payload URL: `https://random-words.trycloudflare.com`
- Content type: `application/json`
- Event: `Just the push event`

### A3. Beperkingen van Route A

- URL verandert bij herstart
- Tunnel stopt als je terminal/proces stopt
- Prima voor demo/test, minder geschikt als "vaste" setup

---

## Route B — Met eigen domein (stabiel, aanbevolen)

## Architectuur (hoog niveau)

```text
GitHub webhook
   |
   v
https://tekton-webhook.<jouw-domein>
   |
   v
Cloudflare Edge
   |
   v
Cloudflare Tunnel (cloudflared pod in cluster)
   |
   v
el-github-push-listener.tekton-pipelines.svc:8080
```

Belangrijk:
- Dit werkt ook als je cluster alleen op host-only netwerk draait.
- Cloudflare bereikt je cluster via de actieve tunnelverbinding, niet via je LAN-IP.

### B1. Tunnel in Cloudflare aanmaken

In Cloudflare dashboard:

1. Ga naar **Zero Trust** (of **Cloudflare One**)
2. Ga naar **Networks -> Tunnels**
3. Klik **Create a tunnel**
4. Kies **Cloudflared**
5. Geef een naam, bijvoorbeeld `ops-demo-workshop`
6. Cloudflare toont een **Tunnel Token** (lange string) — bewaar deze veilig

> **Voor beginners (optioneel):**
> Die token is het wachtwoord waarmee jouw `cloudflared` pod zich aanmeldt.
> Iedereen met deze token kan jouw tunnel gebruiken; behandel hem als secret.

### B2. Public hostname in Cloudflare configureren

In dezelfde tunnel:

1. Ga naar **Public Hostnames**
2. Voeg een hostname toe, bijvoorbeeld:
   - Subdomain: `tekton-webhook`
   - Domain: `<jouw-domein>`
3. Service type: `HTTP`
4. URL: `http://el-github-push-listener.tekton-pipelines.svc.cluster.local:8080`
5. Sla op

> **Voor beginners (optioneel):**
> Deze URL is expres een interne Kubernetes-service.
> Alleen de cloudflared pod hoeft die te kunnen bereiken; internet ziet alleen de publieke hostname.

### B3. Kubernetes manifests toevoegen

Maak de volgende bestanden.

**`manifests/networking/cloudflared/namespace.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloudflare
```

**`manifests/networking/cloudflared/token.secret.yaml`**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-token
  namespace: cloudflare
type: Opaque
stringData:
  token: "PLAK_HIER_JE_CLOUDFLARE_TUNNEL_TOKEN"
```

**`manifests/networking/cloudflared/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2025.2.1
          args:
            - tunnel
            - --no-autoupdate
            - run
            - --token
            - $(TUNNEL_TOKEN)
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflared-token
                  key: token
          resources:
            requests:
              cpu: 20m
              memory: 64Mi
```

**`apps/networking/cloudflared.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudflared
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/networking/cloudflared
  destination:
    server: https://kubernetes.default.svc
    namespace: cloudflare
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Vervang:
- `PLAK_HIER_JE_CLOUDFLARE_TUNNEL_TOKEN`
- `JOUW_FORK_URL`

### B4. Committen en pushen

> **HOST**
> ```bash
> git add apps/networking/cloudflared.yaml manifests/networking/cloudflared/
> git commit -m "feat: add cloudflared tunnel connector"
> git push
> ```

Wacht daarna op `Synced/Healthy`:

> **VM**
> ```bash
> kubectl get application cloudflared -n argocd
> kubectl get pods -n cloudflare
> ```

### B5. Tunnel-status controleren

> **VM**
> ```bash
> kubectl logs -n cloudflare deploy/cloudflared --tail=100
> ```

Zoek op regels zoals "connected" of "registered tunnel connection".

---

## Voorbereiden op Oefening 04 webhook

Als je in Oefening 04 Tekton Triggers hebt geïnstalleerd:

- Bij **Route A**: gebruik je tijdelijke `https://...trycloudflare.com` URL
- Bij **Route B**: gebruik `https://tekton-webhook.<jouw-domein>`

Gebruik in beide gevallen **niet** meer de host-only URL met `192.168.56.200.nip.io`.

---

## Probleemoplossing

| Symptoom | Oplossing |
|---|---|
| cloudflared pod blijft CrashLoopBackOff | Controleer of de tunnel token klopt en niet verlopen/ingetrokken is |
| Tunnel lijkt up, maar webhook geeft 502/504 | Controleer of `el-github-push-listener` service bestaat in `tekton-pipelines` |
| Geen verkeer in Tekton na GitHub push | Controleer GitHub webhook deliveries + event type `push` + secret |
| Argo app `cloudflared` blijft `Unknown` | Controleer of `repoURL` in `apps/networking/cloudflared.yaml` naar jouw fork wijst |
| `trycloudflare.com` URL werkt eerst wel maar later niet meer | Quick tunnel is tijdelijk; start opnieuw of gebruik Route B |

---

## Security-opmerking

Gebruik in een echte omgeving liever:
- externe secret manager voor tunnel token
- aparte Cloudflare tunnel per omgeving
- least-privilege Cloudflare account/API instellingen

Voor deze workshop is één token in een Kubernetes Secret voldoende.

---

## Peek-solution

Wil je een voorbeeld zien zonder alles handmatig te typen?

- Branch: `solution/03b-cloudflare-tunnel`
- Daarin staan:
  - `apps/networking/cloudflared.yaml`
  - `manifests/networking/cloudflared/namespace.yaml`
  - `manifests/networking/cloudflared/token.secret.yaml` (placeholder token)
  - `manifests/networking/cloudflared/deployment.yaml`
