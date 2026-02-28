# Exercise 04 — Tekton Pipeline (GitOps Loop)

**Time**: ~45 min
**Goal**: Build an automated pipeline that bumps the podinfo image tag in Git and watches ArgoCD roll out the new version — the full GitOps CI/CD loop.

---

## What you'll learn
- Tekton concepts: Task, Pipeline, PipelineRun, Workspace
- How a pipeline commits to Git to trigger a GitOps deployment (no container registry needed)
- The full loop: pipeline push → ArgoCD detects → rolling update → new version in browser

---

## The loop visualised

```
You trigger PipelineRun
        │
        ▼
Task 1: clone repo
Task 2: validate manifests (kubectl dry-run)
Task 3: bump image tag  →  deployment.yaml: 6.6.2 → 6.7.0
Task 4: git commit + push
        │
        ▼
ArgoCD polls repo (or click Refresh)
        │
        ▼
ArgoCD syncs podinfo Deployment
        │
        ▼
Rolling update → podinfo v6.7.0 in your browser
```

---

## Prerequisites

Exercises 01–03 complete. podinfo is reachable at **http://podinfo.192.168.56.200.nip.io** and shows version **6.6.2**.

You need:
- A GitHub account with write access to the `ops-demo` repo
- A GitHub Personal Access Token (PAT) with **repo** scope

---

## Steps

### 1. Verify Tekton is installed

The `apps/ci/tekton.yaml` and `apps/ci/pipeline.yaml` ArgoCD Applications are
already in the repo. ArgoCD is installing Tekton via a kustomize remote reference.

Wait for the install to complete (~3–5 min after the app appears in ArgoCD):

```bash
kubectl get pods -n tekton-pipelines
# NAME                                         READY   STATUS    RESTARTS
# tekton-pipelines-controller-xxx              1/1     Running   0
# tekton-pipelines-webhook-xxx                 1/1     Running   0
```

Also check that the pipeline resources are synced:

```bash
kubectl get pipeline -n tekton-pipelines
# NAME                 AGE
# gitops-image-bump    Xm
```

---

### 2. Set up Git credentials

The pipeline needs to push a commit to GitHub. Create a Personal Access Token:

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens** (or classic with `repo` scope)
2. Give it write access to the `ops-demo` repository

Then create the Kubernetes Secret (this command replaces the placeholder Secret if it already exists):

```bash
./scripts/set-git-credentials.sh <your-github-username> <your-pat>
```

Verify:

```bash
kubectl get secret git-credentials -n tekton-pipelines
# NAME              TYPE     DATA   AGE
# git-credentials   Opaque   2      5s
```

---

### 3. Trigger the pipeline

Apply the PipelineRun (this is the only `kubectl apply` you'll run in this exercise):

```bash
kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml
```

Watch it run:

```bash
kubectl get pipelinerun -n tekton-pipelines -w
```

Or follow the logs with tkn (Tekton CLI, optional):

```bash
# If tkn is installed:
tkn pipelinerun logs -f -n tekton-pipelines bump-podinfo-to-670
```

Or follow individual TaskRun pods:

```bash
kubectl get pods -n tekton-pipelines -w
# Once a pod appears, you can:
kubectl logs -n tekton-pipelines <pod-name> -c step-bump --follow
```

The PipelineRun should complete in ~2–3 minutes.

---

### 4. Verify the commit

```bash
# Inside the VM — check the latest commit on the remote
git fetch origin
git log origin/main --oneline -3
# You should see something like:
# a1b2c3d chore(pipeline): bump podinfo to 6.7.0
# ...
```

Or check GitHub directly in your browser.

---

### 5. Watch ArgoCD sync

In the ArgoCD UI, click **Refresh** on the **podinfo** application.

ArgoCD will detect that `manifests/apps/podinfo/deployment.yaml` changed and
start a rolling update.

```bash
kubectl rollout status deployment/podinfo -n podinfo
# deployment "podinfo" successfully rolled out
```

---

### 6. Confirm in the browser

Open **http://podinfo.192.168.56.200.nip.io** — you should now see **version 6.7.0**.

```bash
curl http://podinfo.192.168.56.200.nip.io | jq .version
# "6.7.0"
```

The full loop is complete.

---

## Expected outcome

```
PipelineRun STATUS: Succeeded
deployment.yaml image tag: 6.7.0
podinfo UI version: 6.7.0
```

---

## Re-running the pipeline

The `PipelineRun` name must be unique. To run again:

```bash
# Option A: delete and re-apply with same name
kubectl delete pipelinerun bump-podinfo-to-670 -n tekton-pipelines
kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml

# Option B: create a new run with a different name
kubectl create -f manifests/ci/pipeline/pipelinerun.yaml
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| PipelineRun stuck in "Running" forever | `kubectl describe pipelinerun -n tekton-pipelines bump-podinfo-to-670` |
| `git-credentials` Secret not found | Run `./scripts/set-git-credentials.sh` first |
| Push fails: 403 Forbidden | PAT has insufficient scope — needs `repo` write access |
| Push fails: remote already has this commit | Image tag already at 6.7.0; the pipeline is idempotent (nothing to push) |
| ArgoCD not syncing after push | Click **Refresh** in the UI; default poll interval is 3 min |
| Validate task fails | Check `kubectl apply --dry-run=client -f manifests/apps/podinfo/` manually |

---

## What's next

Exercise 05 is a quick wrap-up: you'll look at the full picture of what you built
and optionally trigger another upgrade cycle to cement the GitOps loop.

If you have time, try the **Bonus Exercise 06**: deploy Prometheus + Grafana and
see cluster and podinfo metrics in a live dashboard.
