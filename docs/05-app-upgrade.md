# Exercise 05 — App Upgrade via GitOps

**Time**: ~15 min (often done as the final step of Exercise 04)
**Goal**: Reflect on the complete GitOps loop you've built and optionally run another upgrade cycle.

---

## What you built

You now have a fully functioning GitOps platform:

```
Git repo (source of truth)
      │
      │  ArgoCD polls every 3 min (or on Refresh)
      ▼
ArgoCD (GitOps engine)
      │  detects drift between Git and cluster
      ▼
Kubernetes cluster
      │  MetalLB assigns LAN IP to Ingress-Nginx
      ▼
Ingress-Nginx (routes by hostname)
      │
      ├─► podinfo.192.168.56.200.nip.io  →  podinfo Deployment
      └─► argocd.192.168.56.200.nip.io   →  ArgoCD UI
```

And a CI pipeline that closes the loop:

```
Tekton PipelineRun
      │
      ├─ validate manifests
      ├─ bump image tag in deployment.yaml
      └─ git push
            │
            ▼
      ArgoCD detects commit → syncs → rolling update
```

---

## Reflect: What makes this "GitOps"?

1. **Git is the source of truth** — the cluster state is always derived from this repo
2. **No manual kubectl apply** — all cluster changes go through Git commits
3. **Drift detection** — if someone manually changes something in the cluster, ArgoCD reverts it
4. **Audit trail** — every cluster change has a corresponding Git commit
5. **Rollback = git revert** — no special tooling needed

---

## Optional: Try a manual upgrade

If the pipeline already bumped podinfo to `6.7.0`, try a manual downgrade to see
the loop in reverse:

```bash
# Edit the image tag back to 6.6.2
vim manifests/apps/podinfo/deployment.yaml
# Change: ghcr.io/stefanprodan/podinfo:6.7.0
# To:     ghcr.io/stefanprodan/podinfo:6.6.2

git add manifests/apps/podinfo/deployment.yaml
git commit -m "chore: downgrade podinfo to 6.6.2 for demo"
git push
```

Watch ArgoCD sync in the UI, then verify:

```bash
curl http://podinfo.192.168.56.200.nip.io | jq .version
# "6.6.2"
```

Now upgrade again via the pipeline:

```bash
kubectl delete pipelinerun bump-podinfo-to-670 -n tekton-pipelines
kubectl apply -f manifests/ci/pipeline/pipelinerun.yaml
```

---

## Optional: Test drift detection

ArgoCD's `selfHeal: true` means it will automatically revert manual cluster changes.

Try bypassing GitOps:

```bash
# Change the image tag directly in the cluster (not via Git)
kubectl set image deployment/podinfo podinfo=ghcr.io/stefanprodan/podinfo:6.5.0 -n podinfo
```

Watch the ArgoCD UI — within seconds you'll see the `podinfo` app go **OutOfSync**,
then ArgoCD reverts it back to whatever tag is in Git. The cluster drifted; GitOps corrected it.

---

## Summary

| Component | Purpose | How deployed |
|-----------|---------|-------------|
| k3s | Kubernetes | Vagrantfile |
| ArgoCD | GitOps engine | bootstrap.sh → self-manages |
| MetalLB | LoadBalancer IPs | ArgoCD |
| Ingress-Nginx | HTTP routing | ArgoCD |
| podinfo | Demo app | ArgoCD |
| Tekton | CI pipeline | ArgoCD |

---

## What's next

If you have time, try **Exercise 06 (Bonus)**: deploy Prometheus + Grafana and
observe your cluster and podinfo metrics in a live dashboard.

Otherwise, join the **final presentation** for a discussion on:
- Why GitOps in production
- What comes next: Vault, ApplicationSets, Argo Rollouts
