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

### 1. Startpunt kiezen

Als je de quickstart uit `README.md` al hebt gedaan
(`./scripts/host/bootstrap-from-host.sh`), dan is bootstrap al uitgevoerd.
Ga in dat geval direct naar stap 3.

Wil je vanaf een blanke VM starten, voer dan bootstrap handmatig uit in de VM:

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

Op je laptop:

```bash
./scripts/host/argocd-ui-tunnel.sh
```

Open **http://localhost:8080**.
Login: `admin` / het wachtwoord uit de output van het script.

---

### 3. Repository in ArgoCD registreren

Het bootstrap-script installeert ArgoCD, maar registreert jouw Git-repo niet in ArgoCD.
Daarom moet je in deze stap expliciet je repo toevoegen, anders blijft `root` op `Unknown`/`authentication required`.

Kies een van deze twee paden:

**Pad A — via ArgoCD UI**

- Ga naar **Settings → Repositories → Connect Repo**
- Vul je repo-URL in
- Auth type: username + password (bij HTTPS)
- Username: je GitHub username
- Password: je GitHub PAT
- Project: `workshop`

**Pad B — via Kubernetes Secret (zonder UI)**

- Maak een Secret in namespace `argocd`
- Label op die Secret: `argocd.argoproj.io/secret-type=repository`
- Secret-data met minimaal:
    - `type: git`
    - `url: <jouw-repo-url>`
    - `username: <jouw-github-user>`
    - `password: <jouw-github-pat>`
    - `project: workshop`

`<jouw-repo-url>` kan technisch HTTPS of SSH zijn, maar:

- Gebruik je een **GitHub PAT** (fine-grained of classic), dan gebruik je een **HTTPS repo-URL**:
    - `https://github.com/<user>/<repo>.git`
- Gebruik je een **SSH repo-URL**:
    - `git@github.com:<user>/<repo>.git`
    - dan authenticate je met een SSH key (niet met PAT).

#### Token/credentials kiezen

Gebruik credentials die read-toegang geven tot je Git-repo.

Als je **GitHub** gebruikt:

1. Ga naar **Settings → Developer settings → [Personal access tokens](https://github.com/settings/tokens)**
2. Maak bij voorkeur een **fine-grained token**
3. Geef de token toegang tot jouw workshop-repo
4. Zet minimaal repository permission:
    - `Contents: Read`

Dit is voldoende voor ArgoCD sync (read-only).  
Gebruik je later Tekton om te pushen, dan heb je `Contents: Read and write` nodig.

Bij HTTPS + PAT geldt:

- `username` = je accountnaam op je Git-provider (bij GitHub: je GitHub username, niet je e-mailadres)
- `password` = de PAT zelf

Een classic token kan ook, met scope `repo`, maar fine-grained heeft de voorkeur.

#### Wat is “Project” in ArgoCD?

Een ArgoCD Project (AppProject) bepaalt welke repos en destinations een set Applications mag gebruiken.
In deze workshop is dat project `workshop` (zie `apps/project.yaml`).

Gebruik hier dus `workshop` als projectwaarde.
`default` werkt soms technisch ook, maar dan omzeil je de workshop-grenzen die we juist willen laten zien.

---

### 4. root.yaml committen en pushen

Het bootstrap-script heeft `apps/root.yaml` aangemaakt met jouw fork-URL.
Dit bestand moet in je repo staan zodat ArgoCD het kan synchroniseren:

```bash
git add apps/root.yaml
git commit -m "feat: add root app-of-apps"
git push
```

---

### 5. De root Application bekijken

In de ArgoCD UI zie je nu de **root** application verschijnen. Klik erop.

- Hij kijkt naar de `apps/` directory in jouw fork
- Alles wat je daar commit, pikt ArgoCD automatisch op

Controleer ook via de CLI:

```bash
kubectl get applications -n argocd
```

---

### 6. ArgoCD zichzelf laten beheren (optioneel maar mooi)

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

Vervang `JOUW_FORK_URL` door jouw fork-URL (staat ook in `apps/root.yaml`).
Commit en push: ArgoCD beheert zichzelf vanaf nu via Git.

---

## Verwacht resultaat

```
NAME     SYNC STATUS   HEALTH STATUS
root     Synced        Healthy
argocd   Synced        Healthy
```

---

## Probleemoplossing

| Symptoom                                         | Oplossing                                                                                                         |
|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| root Application toont "Unknown"                 | Nog niet gepusht, of ArgoCD kan de repo nog niet bereiken — even wachten                                          |
| root toont `Unknown` + `authentication required` | Repository-toegang ontbreekt of credentials zijn fout. Controleer stap 3 (UI of Secret) en refresh daarna de app. |
| Helm install time-out                            | `kubectl get pods -n argocd` — waarschijnlijk nog images aan het downloaden                                       |
| UI toont "Unknown" sync status                   | Klik **Refresh** op de application                                                                                |

---

## Volgende stap

In Oefening 02 deploy je je eerste echte applicatie via GitOps — geen `kubectl apply`, alleen een YAML-bestand in Git.
