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

---

## Stappen

### 1. Tekton installeren via ArgoCD

**`manifests/ci/tekton/kustomization.yaml`**

```yaml
resources:
  - https://storage.googleapis.com/tekton-releases/pipeline/previous/v0.65.1/release.yaml
```

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

**`manifests/ci/pipeline/pipeline.yaml`** — zie de solution branch voor de volledige inhoud, of kopieer uit
`reference-solution`:

> **HOST**
> ```bash
> git show origin/solution/04-tekton-pipeline:manifests/ci/pipeline/pipeline.yaml
> ```

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

**`apps/ci/pipeline.yaml`**

Belangrijk:
- Dit bestand is alleen de ArgoCD `Application` wrapper.
- Daarom is het klein en zie je hier geen Tekton-steps.
- De echte pipeline-steps staan in `manifests/ci/pipeline/pipeline.yaml`
  (clone, validate, bump-image-tag, git-commit-push).

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
Maak een GitHub PAT aan met `repo`-scope en voer daarna een van deze opties uit:

> **VM**
> ```bash
> /vagrant/scripts/vm/set-git-credentials.sh <jouw-github-gebruikersnaam> <jouw-pat>
> ```

Dit maakt een Kubernetes Secret aan in het cluster — **het PAT komt niet in Git**.

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

## Bonus: triggeren via Git webhook (optioneel)

Wil je dat Tekton automatisch runt bij een `git push`?
Dan gebruik je **Tekton Triggers** met een webhook endpoint.

Als je **GitHub** gebruikt, kun je onderstaande manifests direct volgen.
Gebruik je GitLab/Gitea/Bitbucket, dan blijft het patroon hetzelfde maar de interceptor/payload-mapping kan verschillen.

### 1. Triggers resources toevoegen

**`manifests/ci/triggers/kustomization.yaml`**

```yaml
resources:
  - https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
  - https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
  - triggerbinding.yaml
  - triggertemplate.yaml
  - eventlistener.yaml
  - ingress.yaml
```

**`manifests/ci/triggers/triggerbinding.yaml`**

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
  namespace: tekton-pipelines
spec:
  params:
    - name: repo-url
      value: $(body.repository.clone_url)
```

**`manifests/ci/triggers/triggertemplate.yaml`**

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: github-push-template
  namespace: tekton-pipelines
spec:
  params:
    - name: repo-url
      default: https://github.com/JOUW_USERNAME/JOUW_REPO.git
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: webhook-bump-
        namespace: tekton-pipelines
      spec:
        pipelineRef:
          name: gitops-image-bump
        taskRunTemplate:
          serviceAccountName: pipeline-runner
        params:
          - name: repo-url
            value: $(tt.params.repo-url)
          - name: new-tag
            value: "6.7.0"
          - name: git-user-name
            value: "Workshop Pipeline"
          - name: git-user-email
            value: "pipeline@workshop.local"
        workspaces:
          - name: source
            volumeClaimTemplate:
              spec:
                accessModes: [ReadWriteOnce]
                resources:
                  requests:
                    storage: 1Gi
          - name: git-credentials
            secret:
              secretName: git-credentials
```

**`manifests/ci/triggers/eventlistener.yaml`**

```yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-push-listener
  namespace: tekton-pipelines
spec:
  serviceAccountName: pipeline-runner
  triggers:
    - name: on-push
      interceptors:
        - ref:
            name: github
          params:
            - name: secretRef
              value:
                secretName: github-webhook-secret
                secretKey: secretToken
            - name: eventTypes
              value:
                - push
      bindings:
        - ref: github-push-binding
      template:
        ref: github-push-template
```

**`manifests/ci/triggers/ingress.yaml`**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-triggers
  namespace: tekton-pipelines
spec:
  ingressClassName: nginx
  rules:
    - host: tekton-webhook.192.168.56.200.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: el-github-push-listener
                port:
                  number: 8080
```

**`apps/ci/tekton-triggers.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tekton-triggers
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "8"
spec:
  project: workshop
  source:
    repoURL: JOUW_FORK_URL
    targetRevision: HEAD
    path: manifests/ci/triggers
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
> git add apps/ci/tekton-triggers.yaml manifests/ci/triggers/
> git commit -m "feat: voeg Tekton Triggers webhook flow toe"
> git push
> ```

### 2. Webhook secret zetten

> **VM**
> ```bash
> kubectl -n tekton-pipelines create secret generic github-webhook-secret \
>   --from-literal=secretToken='kies-een-sterke-random-string' \
>   --dry-run=client -o yaml | kubectl apply -f -
> ```

### 3. GitHub webhook registreren

- In GitHub: **Settings → Webhooks → Add webhook**
- Payload URL: `http://tekton-webhook.192.168.56.200.nip.io`
- Content type: `application/json`
- Secret: dezelfde waarde als `secretToken`
- Event: **Just the push event**

Daarna maakt elke push een nieuwe `PipelineRun` aan.

---

## Probleemoplossing

| Symptoom                                | Oplossing                                                                                              |
|-----------------------------------------|--------------------------------------------------------------------------------------------------------|
| PipelineRun blijft "Running"            | `kubectl describe pipelinerun -n tekton-pipelines bump-podinfo-to-670`                                 |
| Secret `git-credentials` niet gevonden  | Run in VM: `./scripts/vm/set-git-credentials.sh ...` (na `vagrant ssh` + `cd /vagrant`) of vanaf host: `vagrant ssh -c \"/vagrant/scripts/vm/set-git-credentials.sh ...\"` |
| Push mislukt: 403 Forbidden             | PAT heeft onvoldoende rechten — `repo`-scope vereist                                                   |
| ArgoCD synchroniseert niet              | Klik **Refresh** in de UI                                                                              |
| `root` blijft OutOfSync op app `tekton` | Verwijder de lege `kustomize: {}` uit `apps/ci/tekton.yaml` (Argo normaliseert deze weg in live state) |
| Tekton Dashboard toont standaard Nginx/404 | Controleer `apps/ci/tekton-dashboard.yaml` en `manifests/ci/dashboard/ingress.yaml` host/service/poort |
| Webhook maakt geen PipelineRun aan      | Check `kubectl get eventlistener -n tekton-pipelines` en controleer GitHub webhook URL/secret/eventtype |

---

## Volgende stap

In Oefening 05 kijk je terug op wat je gebouwd hebt en experimenteer je met drift detection.
