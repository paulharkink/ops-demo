# Exercise 06 (Bonus) — Monitoring: Prometheus + Grafana

**Time**: ~60 min
**Goal**: Deploy a full observability stack via ArgoCD and explore cluster + application metrics in Grafana.

---

## What you'll learn
- How to deploy a complex multi-component stack (kube-prometheus-stack) purely via GitOps
- How Prometheus scrapes metrics from Kubernetes and applications
- How to navigate Grafana dashboards for cluster and pod-level metrics

---

## Prerequisites

Exercises 01–03 complete. Ingress-Nginx is running and nip.io URLs are reachable from your laptop.

**Note**: This exercise adds ~700 MB of additional memory usage. It works on an 8 GB VM but may be slow. If the VM feels sluggish, reduce `replicas` or skip Prometheus `storageSpec`.

---

## Steps

### 1. Enable the monitoring Application

The ArgoCD Application manifest for the monitoring stack is already in `apps/monitoring/`.
The root App-of-Apps watches this directory, so the application should already appear
in ArgoCD as **prometheus-grafana**.

Check its sync status:

```bash
kubectl get application prometheus-grafana -n argocd
```

The initial sync takes 5–8 minutes — the kube-prometheus-stack chart is large and
installs many CRDs.

---

### 2. Watch the stack come up

```bash
kubectl get pods -n monitoring -w
# You'll see prometheus, grafana, kube-state-metrics, node-exporter pods appear
```

Once all pods are Running:

```bash
kubectl get ingress -n monitoring
# NAME      CLASS   HOSTS                               ADDRESS
# grafana   nginx   grafana.192.168.56.200.nip.io       192.168.56.200
```

---

### 3. Open Grafana

From your laptop: **http://grafana.192.168.56.200.nip.io**

Login: `admin` / `workshop123`

---

### 4. Explore dashboards

kube-prometheus-stack ships with pre-built dashboards. In the Grafana sidebar:
**Dashboards → Browse**

Useful dashboards for this workshop:

| Dashboard | What to look at |
|-----------|----------------|
| **Kubernetes / Compute Resources / Namespace (Pods)** | CPU + memory per pod in `podinfo` namespace |
| **Kubernetes / Compute Resources / Node (Pods)** | Node-level resource view |
| **Node Exporter / Full** | VM-level CPU, memory, disk, network |

---

### 5. Generate some load on podinfo

In a new terminal, run a simple load loop:

```bash
# Inside the VM
while true; do curl -s http://podinfo.192.168.56.200.nip.io > /dev/null; sleep 0.2; done
```

Switch back to Grafana → **Kubernetes / Compute Resources / Namespace (Pods)** →
set namespace to `podinfo`. You should see CPU usage climb for the podinfo pod.

---

### 6. Explore the GitOps aspect

Every configuration change to the monitoring stack goes through Git.

Try changing the Grafana admin password:

```bash
vim manifests/monitoring/values.yaml
# Change: adminPassword: workshop123
# To:     adminPassword: supersecret
git add manifests/monitoring/values.yaml
git commit -m "chore(monitoring): update grafana admin password"
git push
```

Watch ArgoCD sync the Helm release, then try logging into Grafana with the new password.

---

## Expected outcome

- Grafana accessible at **http://grafana.192.168.56.200.nip.io**
- Prometheus scraping cluster metrics
- Pre-built Kubernetes dashboards visible and populated

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Pods in Pending state | VM may be low on memory; `kubectl describe pod` to confirm |
| Grafana 502 from Nginx | Grafana pod not ready yet; wait and retry |
| No data in dashboards | Prometheus needs ~2 min to scrape first metrics; wait and refresh |
| CRD conflict on sync | First sync installs CRDs; second sync applies resources — retry |

---

## Going further (at home)

- Add a podinfo `ServiceMonitor` so Prometheus scrapes podinfo's `/metrics` endpoint
- Create a custom Grafana dashboard for podinfo request rate and error rate
- Alert on high memory usage with Alertmanager (enable it in `values.yaml`)
