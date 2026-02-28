# Exercise 02 — Deploy podinfo via GitOps

**Time**: ~30 min
**Goal**: Deploy a real application to the cluster purely through Git — no `kubectl apply`.

---

## What you'll learn
- How adding an ArgoCD `Application` manifest to Git is the only deploy action needed
- How to read ArgoCD sync status and application health
- The GitOps feedback loop: commit → push → ArgoCD detects change → cluster updated

---

## Prerequisites

Exercise 01 complete: ArgoCD is running and the root app is Synced.

---

## Background: what is podinfo?

`podinfo` is a tiny Go web app by Stefan Prodan (ArgoCD's author) — often used in
Kubernetes demos. It shows its own version number, has `/healthz` and `/readyz`
endpoints, and looks good in a browser. No external dependencies, no secrets needed.

---

## Steps

### 1. Understand what already exists

The repo already contains the podinfo manifests. Take a look:

```bash
ls manifests/apps/podinfo/
# namespace.yaml  deployment.yaml  service.yaml
```

Open `manifests/apps/podinfo/deployment.yaml` and find the image tag:

```yaml
image: ghcr.io/stefanprodan/podinfo:6.6.2
```

This is version **6.6.2**. Remember it — you'll upgrade it later.

---

### 2. Create the ArgoCD Application

This is the only thing you need to "deploy" the app — tell ArgoCD to watch the manifests:

```bash
cat apps/apps/podinfo.yaml
```

You'll see it points ArgoCD at `manifests/apps/podinfo/` in this repo. The app
already exists in the repo, so ArgoCD's root app will pick it up automatically.

Check ArgoCD now — you should already see a **podinfo** application appearing.

> **The GitOps point**: You didn't run any `kubectl apply` for podinfo. You committed
> `apps/apps/podinfo.yaml` to Git, and ArgoCD synced it. That's the entire workflow.

---

### 3. Watch it sync

```bash
kubectl get application podinfo -n argocd -w
```

Wait until you see `Synced` and `Healthy`. Then:

```bash
kubectl get pods -n podinfo
# NAME                       READY   STATUS    RESTARTS   AGE
# podinfo-xxxxxxxxx-xxxxx    1/1     Running   0          30s
```

---

### 4. Verify the app is working

Port-forward to test locally (inside the VM):

```bash
kubectl port-forward svc/podinfo -n podinfo 9898:80
```

In another terminal (or using curl inside the VM):

```bash
curl http://localhost:9898
# {"hostname":"podinfo-xxx","version":"6.6.2", ...}
```

You can see `"version":"6.6.2"` — that matches the image tag in `deployment.yaml`.

---

### 5. Make a GitOps change

Let's change the UI color to prove the loop works.

Edit `manifests/apps/podinfo/deployment.yaml` and change:
```yaml
value: "#6C48C5"
```
to any hex color you like, e.g.:
```yaml
value: "#2ecc71"
```

Commit and push:

```bash
git add manifests/apps/podinfo/deployment.yaml
git commit -m "chore: change podinfo UI color"
git push
```

Within ~3 minutes (ArgoCD's default poll interval) you'll see the pod restart and
the new color appear. You can also click **Refresh** in the ArgoCD UI to trigger
an immediate sync.

---

## Expected outcome

```
NAME      SYNC STATUS   HEALTH STATUS
podinfo   Synced        Healthy
```

```bash
curl http://localhost:9898 | jq .version
# "6.6.2"
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Application stuck in "Progressing" | `kubectl describe pod -n podinfo` — usually image pull |
| `ImagePullBackOff` | Image was pre-pulled; run `kubectl get events -n podinfo` |
| ArgoCD shows OutOfSync after push | Click **Refresh** or wait 3 min for next poll |

---

## What's next

podinfo is running but only accessible via port-forward. In Exercise 03 you'll
expose it on your LAN using MetalLB (a real load balancer) and Ingress-Nginx,
so you can reach it from your laptop's browser without any port-forward.
