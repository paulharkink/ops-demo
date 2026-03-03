# Oefening 04 — Tekton Pipeline

**Tijd**: ~45 minuten
**Doel**: Een pipeline bouwen die automatisch de image-tag in Git aanpast en ArgoCD de update laat uitrollen — de
volledige GitOps CI/CD-loop.

---

## Wat je leert

- Tekton-concepten: Task, Pipeline, PipelineRun, Workspace
- Hoe een pipeline via een Git-commit een GitOps-deployment triggert (geen container registry nodig)
- De volledige loop: pipeline push → ArgoCD detecteert → rolling update → nieuwe versie in browser

---

## Leeswijzer

> **Voor beginners (optioneel):**
> Oefening 04 heeft de meeste moving parts.
> Alle alinea's met "Waarom dit" kun je zien als mini-achtergrond.
> Gevorderden kunnen die overslaan en direct de snippets volgen.

## Vooraf lezen (optioneel)

Als Tekton nieuw voor je is, skim eerst deze pagina's:

- Tekton docs (startpunt): https://tekton.dev/docs/
- Core concepten (Tasks, Pipelines, PipelineRuns): https://tekton.dev/docs/pipelines/
- Eerste voorbeeldpipeline: https://tekton.dev/docs/getting-started/pipelines/
- Kustomize docs (startpunt): https://kubectl.docs.kubernetes.io/references/kustomize/

In deze workshop gebruiken we **Kustomize** voor het eerst in **stap 1**
met `manifests/ci/tekton/kustomization.yaml`.

---

## De loop

```
Jij triggert een PipelineRun
        │
        ▼
Task 1: clone repo
Task 2: valideer manifests (kubectl dry-run)
Task 3: pas image-tag aan  →  deployment.yaml: 6.6.2 → 6.7.0
Task 4: git commit + push
        │
        ▼
ArgoCD detecteert de commit
        │
        ▼
ArgoCD synchroniseert de podinfo Deployment
        │
        ▼
Rolling update → podinfo v6.7.0 in je browser
```

---

## Vereisten

Oefeningen 01–03 afgerond. podinfo is bereikbaar via **http://podinfo.192.168.56.200.nip.io** en toont versie **6.6.2**.

Je hebt nodig:

- Een GitHub Personal Access Token (PAT) met **repo**-scope (lezen + schrijven)
  Maak er direct een aan via:
  - Fine-grained: https://github.com/settings/personal-access-tokens/new
  - Classic: https://github.com/settings/tokens/new

---

## Stappen

### 1. Tekton installeren via ArgoCD

**`manifests/ci/tekton/kustomization.yaml`**

```yaml
resources:
  - https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.65.1/release.yaml
patches:
  - path: namespace-podsecurity-patch.yaml
    target:
      kind: Namespace
      name: tekton-pipelines
```

Waarom dit:

- `release.yaml` installeert Tekton Pipelines (controller, webhook, CRDs).
- De `patches` regel past de namespace aan die al in de upstream release zit.
- Zonder patch faalt de eerste TaskRun vaak op Pod Security Admission (PSA).
- Pod Security Admission (PSA) is een Kubernetes-mechanisme dat per namespace bepaalt hoe streng pod-beveiliging wordt
  afgedwongen.
- In deze oefening zet de upstream Tekton install de namespace effectief op `restricted`; dat profiel eist o.a.
  `runAsNonRoot`, `seccompProfile` en `allowPrivilegeEscalation=false`.
- Tekton runtime-pods (zoals `prepare` en `step-*`) voldoen in deze setup niet altijd aan die eisen, waardoor je direct
  `PodAdmissionFailed` krijgt voordat je pipeline-logica start.

**`manifests/ci/tekton/namespace-podsecurity-patch.yaml`**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tekton-pipelines
  labels:
    pod-security.kubernetes.io/enforce: privileged
```

Waarom dit:

- Tekton maakt zelf tijdelijke pods aan per TaskRun (`prepare`, `step-*`).
- Met `enforce=restricted` worden die pods in deze workshop-setup afgewezen.
- Deze patch maakt de oefening reproduceerbaar op de single-node VM.
- `enforce=privileged` betekent hier niet "alles in je cluster is onveilig", maar alleen dat deze ene namespace niet
  door PSA wordt geblokkeerd.
- We kiezen dit bewust als workshop trade-off: focus op GitOps/Tekton-flow, niet op PSA-hardening.
- In productie kies je meestal niet `privileged`, maar harden je de Tekton setup zodat hij onder `baseline`/`restricted`
  draait.

**`apps/ci/tekton.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tekton
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/ci/tekton
  destination:
    server: https://kubernetes.default.svc
    namespace: tekton-pipelines
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
> git add apps/ci/tekton.yaml manifests/ci/tekton/
> git commit -m "feat: installeer Tekton via ArgoCD"
> git push
> ```

Wacht tot Tekton draait (~3–5 minuten):

> **VM**
> ```bash
> kubectl get pods -n tekton-pipelines
> # tekton-pipelines-controller-xxx   1/1   Running
> # tekton-pipelines-webhook-xxx      1/1   Running
> ```

Wat je hier valideert:

- De Tekton controller verwerkt Pipeline/Task resources.
- De Tekton webhook default/valideert objecten bij `kubectl apply`.
- Als deze pods niet `Running` zijn, heeft het geen zin om door te gaan.

---

### 2. Pipeline-resources aanmaken

**`manifests/ci/pipeline/serviceaccount.yaml`**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pipeline-runner
  namespace: tekton-pipelines
```

Waarom dit:

- Deze serviceaccount draait de pipeline pods.
- Alle permissies voor `validate` en eventuele cluster-calls hangen aan dit account.

**`manifests/ci/pipeline/pipeline.yaml`** — zie de solution branch voor de volledige inhoud, of kopieer uit
`reference-solution`: 

> **HOST**
> ```bash
> git show origin/solution/04-tekton-pipeline:manifests/ci/pipeline/pipeline.yaml
> ```

Wat er in die pipeline zit:

- `clone`: clonet jouw repo met credentials uit `git-credentials`.
- `validate`: doet client-side manifestvalidatie op de podinfo manifests.
- `bump-image-tag`: wijzigt de image tag in `deployment.yaml`.
- `git-commit-push`: commit + push naar `main`, waarna ArgoCD de wijziging oppakt.

**`manifests/ci/pipeline/pipelinerun.yaml`**

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bump-podinfo-to-670
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: gitops-image-bump
  taskRunTemplate:
    serviceAccountName: pipeline-runner
  params:
    - name: repo-url
      value: JOUW_FORK_URL
    - name: new-tag
      value: "6.7.0"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ ReadWriteOnce ]
          resources:
            requests:
              storage: 1Gi
    - name: git-credentials
      secret:
        secretName: git-credentials
```

Waarom deze velden belangrijk zijn:

- `pipelineRef`: kiest welke pipeline je start.
- `params`: bepaalt repo en doelversie zonder de pipeline-definitie te wijzigen.
- `workspaces.source`: tijdelijk werkvolume voor clone/edit/commit.
- `workspaces.git-credentials`: secret mount voor Git auth.

**`apps/ci/pipeline.yaml`**

Belangrijk:

- Dit bestand is alleen de ArgoCD `Application` wrapper.
- Daarom is het klein en zie je hier geen Tekton-steps.
- De echte pipeline-steps staan in `manifests/ci/pipeline/pipeline.yaml`
  (clone, validate, bump-image-tag, git-commit-push).
- ArgoCD beheert dus alleen Tekton resources; de pipeline runtime gebeurt in Tekton zelf.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: workshop-pipeline
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "7"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/ci/pipeline
  destination:
    server: https://kubernetes.default.svc
    namespace: tekton-pipelines
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

> **HOST**
> ```bash
> git add apps/ci/pipeline.yaml manifests/ci/pipeline/
> git commit -m "feat: voeg pipeline-resources toe"
> git push
> ```

---

### 3. Tekton Dashboard zichtbaar maken (UI)

Maak een aparte Tekton Dashboard app, met Ingress zodat je PipelineRuns in de browser ziet.

**`manifests/ci/dashboard/kustomization.yaml`**

```yaml
resources:
  - https://storage.googleapis.com/tekton-releases/dashboard/latest/release-full.yaml
  - ingress.yaml
```

Waarom dit:

- `release-full.yaml` installeert de dashboard backend + service.
- `ingress.yaml` maakt de UI bereikbaar via dezelfde ingress-nginx die je in oefening 03 bouwde.

**`manifests/ci/dashboard/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-dashboard
  namespace: tekton-pipelines
spec:
  ingressClassName: nginx
  rules:
    - host: tekton.192.168.56.200.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tekton-dashboard
                port:
                  number: 9097
```

**`apps/ci/tekton-dashboard.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tekton-dashboard
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "6"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/ci/dashboard
  destination:
    server: https://kubernetes.default.svc
    namespace: tekton-pipelines
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

> **HOST**
> ```bash
> git add apps/ci/tekton-dashboard.yaml manifests/ci/dashboard/
> git commit -m "feat: voeg Tekton Dashboard met ingress toe"
> git push
> ```

Open daarna: **http://tekton.192.168.56.200.nip.io**

---

### 4. Git-credentials instellen

Dit is een verplichte stap vóór je de PipelineRun triggert.
Zonder `git-credentials` secret faalt de `clone` task direct.

De pipeline moet kunnen pushen naar jouw fork.
Maak een GitHub PAT aan met `repo`-scope en voer daarna een van deze opties uit.
Direct links:

- Fine-grained token: https://github.com/settings/personal-access-tokens/new
- Classic token: https://github.com/settings/tokens/new

> **VM**
> ```bash
> /vagrant/scripts/vm/set-git-credentials.sh <jouw-github-gebruikersnaam> <jouw-pat>
> ```

Dit maakt een Kubernetes Secret aan in het cluster — **het PAT komt niet in Git**.

Tip:

- Bij GitHub PAT over HTTPS kun je als username je GitHub username gebruiken.
- `x-access-token` als username werkt vaak ook, zolang password de PAT is.

---

### 5. Pipeline triggeren

Controleer eerst dat stap 3 gelukt is.
Pas daarna de PipelineRun starten:

> **VM**
> ```bash
> kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml
> ```

Volg de voortgang:

> **VM**
> ```bash
> kubectl get pipelinerun -n tekton-pipelines -w
> ```

Of per pod:

> **VM**
> ```bash
> kubectl get pods -n tekton-pipelines -w
> ```

De PipelineRun duurt ~2–3 minuten.

Wat je zou moeten zien:

- eerst `clone`,
- daarna `validate`,
- dan `bump-image-tag`,
- en als laatste `git-commit-push`.

---

### 6. Controleer de commit

> **HOST**
> ```bash
> git fetch origin
> git log origin/main --oneline -3
> # Je ziet: chore(pipeline): bump podinfo to 6.7.0
> ```

---

### 7. ArgoCD laten synchroniseren

Klik **Refresh** op de **podinfo** application in ArgoCD, of wacht op het automatische poll-interval.

> **VM**
> ```bash
> kubectl rollout status deployment/podinfo -n podinfo
> ```

Waarom dit nodig is:

- De pipeline praat niet direct met de podinfo Deployment.
- De pipeline pusht alleen Git; ArgoCD voert de daadwerkelijke rollout uit.

---

### 8. Controleer in de browser

Open **http://podinfo.192.168.56.200.nip.io** — je ziet nu versie **6.7.0**.

> **HOST**
> ```bash
> curl http://podinfo.192.168.56.200.nip.io | jq .version
> # "6.7.0"
> ```

---

## Pipeline opnieuw uitvoeren

De naam van een PipelineRun moet uniek zijn:

> **VM**
> ```bash
> kubectl delete pipelinerun bump-podinfo-to-670 -n tekton-pipelines
> kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml
> ```

---

## Probleemoplossing

| Symptoom                                   | Oplossing                                                                                                                                                                  |
|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| PipelineRun blijft "Running"               | `kubectl describe pipelinerun -n tekton-pipelines bump-podinfo-to-670`                                                                                                     |
| Secret `git-credentials` niet gevonden     | Run in VM: `./scripts/vm/set-git-credentials.sh ...` (na `vagrant ssh` + `cd /vagrant`) of vanaf host: `vagrant ssh -c \"/vagrant/scripts/vm/set-git-credentials.sh ...\"` |
| Push mislukt: 403 Forbidden                | PAT heeft onvoldoende rechten — `repo`-scope vereist                                                                                                                       |
| ArgoCD synchroniseert niet                 | Klik **Refresh** in de UI                                                                                                                                                  |
| `root` blijft OutOfSync op app `tekton`    | Verwijder de lege `kustomize: {}` uit `apps/ci/tekton.yaml` (Argo normaliseert deze weg in live state)                                                                     |
| PipelineRun faalt met `PodAdmissionFailed` | Controleer dat `tekton-pipelines` label `pod-security.kubernetes.io/enforce=privileged` heeft (via `manifests/ci/tekton/namespace-podsecurity-patch.yaml`)                 |
| Tekton Dashboard toont standaard Nginx/404 | Controleer `apps/ci/tekton-dashboard.yaml` en `manifests/ci/dashboard/ingress.yaml` host/service/poort                                                                     |

---

## Volgende stap

In Oefening 05 kijk je terug op wat je gebouwd hebt en experimenteer je met drift detection.
