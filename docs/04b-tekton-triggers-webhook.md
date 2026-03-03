# Oefening 04b (Bonus) — Tekton Triggers via webhook

**Tijd**: ~30–45 minuten
**Doel**: PipelineRuns automatisch starten via inkomende git-webhooks.

---


Wil je dat Tekton automatisch runt bij een `git push`?
Dan gebruik je **Tekton Triggers** met een webhook endpoint.

Als je **GitHub** gebruikt, kun je onderstaande manifests direct volgen.
Gebruik je GitLab/Gitea/Bitbucket, dan blijft het patroon hetzelfde maar de interceptor/payload-mapping kan verschillen.

> [!IMPORTANT]
> In deze workshop draait de cluster op een VirtualBox host-only netwerk (`192.168.56.x`).
> Dat endpoint is niet publiek bereikbaar vanaf GitHub.
> Dus: GitHub kan `tekton-webhook.192.168.56.200.nip.io` niet direct aanroepen.
>
> Voor echte GitHub webhooks heb je een brug nodig, bijvoorbeeld:
> - een publieke tunnel (`ngrok`, `cloudflared tunnel`)
> - een webhook relay (`smee.io`)
> - of een publiek bereikbare cluster endpoint (geen host-only-only setup)
>
> Als je **Oefening 03b** hebt gedaan, gebruik dan je Cloudflare Tunnel URL
> (bijv. `https://tekton-webhook.<jouw-domein>`) als webhook endpoint.

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
                accessModes: [ ReadWriteOnce ]
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

Zonder tunnel/relay of publiek endpoint zal GitHub deze URL niet kunnen bereiken.
Met zo'n brug maakt elke push een nieuwe `PipelineRun` aan.

---


---

## Opmerking

Deze bonus-oefening staat los van het kernprogramma en wordt alleen apart getest/uitgerold.
