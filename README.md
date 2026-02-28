# Kubernetes GitOps Workshop

Twee en een half tot vier uur hands-on cluster operations met ArgoCD, MetalLB, Ingress-Nginx en Tekton. Alles draait
lokaal op een single-node k3s cluster in een VM.

---

## Vóór je begint

Je hebt drie dingen nodig op je laptop. Installeer ze de dag van tevoren — niet op de dag zelf.

| Tool           | Download                                                            |
|----------------|---------------------------------------------------------------------|
| VirtualBox 7.x | https://www.virtualbox.org/wiki/Downloads — op Windows: reboot alleen als installer/Windows daarom vraagt |
| Vagrant 2.4.x  | https://developer.hashicorp.com/vagrant/downloads                   |
| Git            | https://git-scm.com/downloads                                       |

Minimaal 12 GB vrij RAM en ~15 GB schijfruimte. Snelle check:

```bash
VBoxManage --version && vagrant --version && git --version
```

Als één van de drie niets teruggeeft: installeren en opnieuw proberen.

---

## Aan de slag

**Fork eerst de repo** naar je eigen GitHub-account — ga naar https://github.com/paulharkink/ops-demo en klik Fork. Zo
kun je zelf pushen zonder dat je toegang nodig hebt tot de originele repo.

1. Clone je fork op je host-machine.
```bash
git clone https://github.com/JOUW_USERNAME/ops-demo.git && cd ops-demo
```
2. Start de VM.
```bash
vagrant up
```
3. Run bootstrap vanaf je host (script voert bootstrap in de VM uit).
```bash
./scripts/bootstrap-from-host.sh
```
```powershell
./scripts/bootstrap-from-host.ps1
```
4. Open ArgoCD UI via tunnel.
```bash
./scripts/argocd-ui-tunnel.sh
```
```powershell
./scripts/argocd-ui-tunnel.ps1
```
5. Open in je browser:
```text
https://localhost:8080
```

Volg daarna de oefeningen in volgorde. Zie [docs/vm-setup.md](docs/vm-setup.md) als er iets misgaat bij de VM.

Belangrijk:
- Je hoeft het VM-IP niet te weten om in te loggen of te tunnelen; gebruik `vagrant ssh`.
- Je hoeft de repo niet opnieuw in de VM te clonen: Vagrant mount je host-repo automatisch als `/vagrant`.

---

## Oefeningen

| #  | Oefening                    | Gids                                                       | Type  | Tijd   |
|----|-----------------------------|------------------------------------------------------------|-------|--------|
| 01 | ArgoCD bootstrappen         | [docs/01-argocd-bootstrap.md](docs/01-argocd-bootstrap.md) | Kern  | 30 min |
| 02 | podinfo deployen via GitOps | [docs/02-deploy-podinfo.md](docs/02-deploy-podinfo.md)     | Kern  | 30 min |
| 03 | MetalLB + Ingress-Nginx     | [docs/03-metallb-ingress.md](docs/03-metallb-ingress.md)   | Kern  | 45 min |
| 04 | Tekton pipeline             | [docs/04-tekton-pipeline.md](docs/04-tekton-pipeline.md)   | Kern  | 45 min |
| 05 | App upgrade + reflectie     | [docs/05-app-upgrade.md](docs/05-app-upgrade.md)           | Kern  | 15 min |
| 06 | Prometheus + Grafana        | [docs/06-monitoring.md](docs/06-monitoring.md)             | Bonus | 60 min |

Beginners: focus op 01–03 (~1u45m). De rest: probeer 01–05 te halen.

---

## Stack

| Component             | Rol                     | Versie                 |
|-----------------------|-------------------------|------------------------|
| k3s                   | Kubernetes              | v1.31.4                |
| ArgoCD                | GitOps engine           | v2.13.x (chart 7.7.11) |
| MetalLB               | Bare-metal LoadBalancer | v0.14.9                |
| Ingress-Nginx         | HTTP-routing            | chart 4.12.0           |
| Tekton                | CI-pipeline             | v0.65.1                |
| podinfo               | Demo-app                | 6.6.2 → 6.7.0          |
| kube-prometheus-stack | Observability (bonus)   | chart 68.4.4           |

---

## Vastgelopen?

Elke solution branch is cumulatief — hij bevat alles t/m die oefening. Je kunt een PR openen van een solution branch
naar jouw eigen branch om precies te zien wat er mist.

| Branch                         | Bevat                               |
|--------------------------------|-------------------------------------|
| `solution/01-argocd-bootstrap` | ArgoCD draait                       |
| `solution/02-deploy-podinfo`   | podinfo gesynchroniseerd via ArgoCD |
| `solution/03-metallb-ingress`  | LAN-toegang via MetalLB + Ingress   |
| `solution/04-tekton-pipeline`  | Volledige GitOps CI-loop            |
| `solution/05-app-upgrade`      | podinfo op v6.7.0                   |
| `solution/06-monitoring`       | Prometheus + Grafana actief         |

---

## Netwerk

```
Jouw laptop
    │  192.168.56.x (VirtualBox host-only)
    ▼
VM: 192.168.56.10
    └── MetalLB pool: 192.168.56.200–192.168.56.220
            └── 192.168.56.200  →  Ingress-Nginx
                    ├── podinfo.192.168.56.200.nip.io
                    ├── argocd.192.168.56.200.nip.io
                    └── grafana.192.168.56.200.nip.io  (bonus)
```
