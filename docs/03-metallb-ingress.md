# Exercise 03 — MetalLB + Ingress-Nginx (LAN exposure)

**Time**: ~45 min
**Goal**: Expose podinfo and the ArgoCD UI on a real LAN IP — accessible from your laptop's browser without any port-forward.

---

## What you'll learn
- What MetalLB is and why you need it in a bare-metal / local Kubernetes cluster
- How a LoadBalancer service gets a real IP via L2 ARP
- How Ingress-Nginx routes HTTP traffic by hostname
- `nip.io` — a public wildcard DNS service for local development

---

## Background

In cloud Kubernetes (EKS, GKE, AKS), `type: LoadBalancer` automatically provisions a cloud load balancer with a public IP. On bare metal or local VMs, nothing does that — so pods stay unreachable.

**MetalLB** fills that gap: it watches for `LoadBalancer` services and assigns IPs from a pool you define. In L2 mode it uses ARP to answer "who has 192.168.56.200?" — so your laptop routes directly to the VM.

**Ingress-Nginx** is a single LoadBalancer service that MetalLB gives one IP. All your apps share that IP — Nginx routes to the right service based on the `Host:` header.

**nip.io** is a public DNS wildcard: `anything.192.168.56.200.nip.io` resolves to `192.168.56.200`. No `/etc/hosts` editing needed.

---

## Steps

### 1. Enable MetalLB

The ArgoCD Application manifests for MetalLB are already in this repo. The root
App-of-Apps watches the `apps/` directory, which includes `apps/networking/`.
They are already being applied — MetalLB just needs a moment to become healthy.

Check MetalLB is running:

```bash
kubectl get pods -n metallb-system
# NAME                          READY   STATUS    RESTARTS   AGE
# controller-xxx                1/1     Running   0          Xm
# speaker-xxx                   1/1     Running   0          Xm
```

Check the IP pool is configured:

```bash
kubectl get ipaddresspool -n metallb-system
# NAME            AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
# workshop-pool   true          false             ["192.168.56.200-192.168.56.220"]
```

---

### 2. Enable Ingress-Nginx

Similarly, `apps/networking/ingress-nginx.yaml` is already in the repo. Wait for it
to become Synced in ArgoCD, then:

```bash
kubectl get svc -n ingress-nginx
# NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# ingress-nginx-controller             LoadBalancer   10.43.x.x      192.168.56.200   80:xxx,443:xxx
```

The `EXTERNAL-IP` column shows `192.168.56.200`. MetalLB assigned it.

From your **laptop** (not the VM), verify:

```bash
curl http://192.168.56.200
# 404 from Nginx — correct! No ingress rule yet, but Nginx is reachable.
```

---

### 3. Add a podinfo Ingress

The Ingress resource is already in `manifests/apps/podinfo/ingress.yaml`.
ArgoCD will sync it automatically. After sync:

```bash
kubectl get ingress -n podinfo
# NAME      CLASS   HOSTS                              ADDRESS          PORTS
# podinfo   nginx   podinfo.192.168.56.200.nip.io      192.168.56.200   80
```

Open from your **laptop browser**: **http://podinfo.192.168.56.200.nip.io**

You should see the podinfo UI with version 6.6.2.

---

### 4. Enable the ArgoCD ingress

Now let's expose ArgoCD itself on a nice URL. Open `manifests/argocd/values.yaml`
and find the commented-out ingress block near the `server:` section:

```yaml
  # ── Exercise 03: uncomment this block after Ingress-Nginx is deployed ──────
  # ingress:
  #   enabled: true
  # ...
```

Uncomment the entire block (remove the `#` characters):

```yaml
  ingress:
    enabled: true
    ingressClassName: nginx
    hostname: argocd.192.168.56.200.nip.io
    annotations:
      nginx.ingress.kubernetes.io/ssl-passthrough: "false"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
```

Commit and push:

```bash
git add manifests/argocd/values.yaml
git commit -m "feat(ex03): enable ArgoCD ingress"
git push
```

ArgoCD will detect the change, upgrade its own Helm release, and create the Ingress.
Within a minute or two:

```bash
kubectl get ingress -n argocd
# NAME            CLASS   HOSTS                              ADDRESS
# argocd-server   nginx   argocd.192.168.56.200.nip.io      192.168.56.200
```

Open from your laptop: **http://argocd.192.168.56.200.nip.io**

---

## Expected outcome

| URL | App |
|-----|-----|
| http://podinfo.192.168.56.200.nip.io | podinfo v6.6.2 |
| http://argocd.192.168.56.200.nip.io  | ArgoCD UI |

Both accessible from your laptop without any port-forward.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `EXTERNAL-IP` is `<pending>` on ingress-nginx svc | MetalLB not ready yet — check `kubectl get pods -n metallb-system` |
| Curl to 192.168.56.200 times out from laptop | VirtualBox host-only adapter not configured; check `VBoxManage list hostonlyifs` |
| `nip.io` doesn't resolve | Temporary DNS issue; try again or use `/etc/hosts` with `192.168.56.200 podinfo.local` |
| ArgoCD ingress gives 502 | Wait for ArgoCD to restart after values change; ArgoCD now runs in insecure (HTTP) mode |

---

## What's next

In Exercise 04 you'll build a Tekton pipeline that:
1. Validates manifests
2. Bumps the podinfo image tag from `6.6.2` to `6.7.0` in `deployment.yaml`
3. Pushes the commit — and ArgoCD picks it up automatically
