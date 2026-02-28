# Oefening 01 — ArgoCD bootstrappen

**Tijd**: ~30 minuten
**Doel**: ArgoCD aan de praat krijgen op je cluster en de App-of-Apps opzetten.

---

## Wat je leert

- ArgoCD installeren via Helm
- Het App-of-Apps patroon: één ArgoCD Application die alle andere beheert
- Hoe ArgoCD je Git-repo in de gaten houdt en de cluster-staat synchroniseert

---

## Vereisten

De VM draait en je bent ingelogd:

```bash
vagrant ssh
cd /vagrant
kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# ops-demo   Ready    control-plane,master   ...
```

---

## Stappen

### 1. Bootstrap-script uitvoeren

```bash
./scripts/vm/bootstrap.sh
```

Het script doet het volgende:
1. Detecteert de URL van jouw fork op basis van `git remote`
2. Maakt de `argocd` namespace aan
3. Installeert ArgoCD via Helm
4. Past `apps/project.yaml` toe
5. Genereert `apps/root.yaml` met jouw fork-URL en past het toe

Aan het einde zie je het admin-wachtwoord. **Kopieer het nu.**

---

### 2. ArgoCD UI openen

In een tweede terminal op je laptop:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open **https://localhost:8080** (accepteer het self-signed certificaat).
Login: `admin` / het wachtwoord uit de output van het script.

---

### 3. root.yaml committen en pushen

Het bootstrap-script heeft `apps/root.yaml` aangemaakt met jouw fork-URL. Dit bestand moet in je repo staan zodat ArgoCD het kan synchroniseren:

```bash
git add apps/root.yaml
git commit -m "feat: add root app-of-apps"
git push
```

---

### 4. De root Application bekijken

In de ArgoCD UI zie je nu de **root** application verschijnen. Klik erop.

- Hij kijkt naar de `apps/` directory in jouw fork
- Alles wat je daar commit, pikt ArgoCD automatisch op

Controleer ook via de CLI:

```bash
kubectl get applications -n argocd
```

---

### 5. ArgoCD zichzelf laten beheren (optioneel maar mooi)

Maak `apps/argocd.yaml` aan:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: workshop
  sources:
    - repoURL: https://argoproj.github.io/argo-helm
      chart: argo-cd
      targetRevision: "7.7.11"
      helm:
        valueFiles:
          - $values/manifests/argocd/values.yaml
    - repoURL: JOUW_FORK_URL
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Vervang `JOUW_FORK_URL` door jouw fork-URL (staat ook in `apps/root.yaml`). Commit en push — ArgoCD beheert zichzelf vanaf nu via Git.

---

## Verwacht resultaat

```
NAME     SYNC STATUS   HEALTH STATUS
root     Synced        Healthy
argocd   Synced        Healthy
```

---

## Probleemoplossing

| Symptoom | Oplossing |
|----------|-----------|
| root Application toont "Unknown" | Nog niet gepusht, of ArgoCD kan de repo nog niet bereiken — even wachten |
| Helm install time-out | `kubectl get pods -n argocd` — waarschijnlijk nog images aan het downloaden |
| UI toont "Unknown" sync status | Klik **Refresh** op de application |

---

## Volgende stap

In Oefening 02 deploy je je eerste echte applicatie via GitOps — geen `kubectl apply`, alleen een YAML-bestand in Git.
