# Exercise 01 — Bootstrap ArgoCD

**Time**: ~30 min
**Goal**: Get ArgoCD running on your local k3s cluster and apply the App-of-Apps root application.

---

## What you'll learn
- How to install ArgoCD via Helm
- The App-of-Apps pattern: one ArgoCD Application that manages all others
- How ArgoCD watches a Git repository and syncs cluster state

---

## Prerequisites

Make sure your VM is up and you are SSHed in:

```bash
vagrant up        # first time takes ~10 min (downloads images)
vagrant ssh
cd /vagrant
```

Verify k3s is healthy:

```bash
kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# ops-demo   Ready    control-plane,master   Xm    v1.31.x+k3s1
```

---

## Steps

### 1. Run the bootstrap script

```bash
./scripts/bootstrap.sh
```

This script:
1. Creates the `argocd` namespace
2. Installs ArgoCD via Helm (chart 7.7.11 → ArgoCD v2.13.x)
3. Applies `apps/project.yaml` — a permissive `AppProject` for all workshop apps
4. Applies `apps/root.yaml` — the App-of-Apps entry point

At the end it prints the admin password. **Copy it now.**

---

### 2. Open the ArgoCD UI

In a second terminal on your laptop (not the VM), run:

```bash
vagrant ssh -- -L 8080:localhost:8080 &
# or, inside the VM:
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open **https://localhost:8080** in your browser (accept the self-signed cert).

Login: `admin` / `<password from script output>`

---

### 3. Explore the root Application

In the ArgoCD UI you should see one application: **root**.

- Click it. Notice it is syncing the `apps/` directory from this repo.
- It found `apps/argocd.yaml` and `apps/project.yaml` and is managing them.
- ArgoCD is now **self-managing** — any change you push to `apps/` will be picked up automatically.

```bash
# Confirm from the CLI too
kubectl get applications -n argocd
```

---

### 4. Check the self-managing ArgoCD app

Click the **argocd** application in the UI. It should show **Synced / Healthy**.

ArgoCD is now reconciling its own Helm release from Git. If you push a change to
`manifests/argocd/values.yaml`, ArgoCD will apply it to itself.

---

## Expected outcome

```
NAME     SYNC STATUS   HEALTH STATUS
argocd   Synced        Healthy
root     Synced        Healthy
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `kubectl get nodes` shows NotReady | Wait 30–60 s; k3s is starting |
| Helm install fails with timeout | Run `kubectl get pods -n argocd` — if image pull is slow, wait |
| UI shows "Unknown" sync status | Click **Refresh** on the application |
| Port-forward drops | Re-run the `kubectl port-forward` command |

---

## What's next

In Exercise 02 you will deploy your first application — **podinfo** — purely through
Git: no `kubectl apply`, just a YAML file committed to the repo.
