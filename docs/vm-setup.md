# VM Setup — Getting Started

Everything runs inside a VirtualBox VM provisioned by Vagrant.
This page walks you through starting the VM and verifying it is healthy before the workshop begins.

---

## Requirements (install on your laptop before the workshop)

| Tool | Version | Download |
|------|---------|----------|
| VirtualBox | 7.x | https://www.virtualbox.org/wiki/Downloads |
| Vagrant | 2.4.x | https://developer.hashicorp.com/vagrant/downloads |
| Git | any | https://git-scm.com/downloads |

**RAM**: The VM uses 8 GB. Your laptop should have at least 12 GB total RAM free.
**Disk**: ~15 GB free (Vagrant box ~1 GB + k3s images ~5 GB + workspace).

---

## Step 1 — Clone the repo

```bash
git clone https://github.com/innspire/ops-demo.git
cd ops-demo
```

---

## Step 2 — Start the VM

```bash
vagrant up
```

First run takes **10–15 minutes**: Vagrant downloads the Ubuntu 24.04 box, installs
k3s, Helm, yq, and pre-pulls the workshop container images. Subsequent `vagrant up`
calls start the existing VM in under a minute.

You should see:
```
════════════════════════════════════════════════════════
  VM provisioned successfully!
  SSH:       vagrant ssh
  Next step: follow docs/vm-setup.md to verify, then
             run scripts/bootstrap.sh to install ArgoCD
════════════════════════════════════════════════════════
```

---

## Step 3 — SSH into the VM

```bash
vagrant ssh
```

You are now inside the VM. All workshop commands run here unless stated otherwise.

---

## Step 4 — Verify the setup

```bash
# 1. k3s is running
kubectl get nodes
# NAME       STATUS   ROLES                  AGE   VERSION
# ops-demo   Ready    control-plane,master   Xm    v1.31.x+k3s1

# 2. Helm is available
helm version
# version.BuildInfo{Version:"v3.16.x", ...}

# 3. The workshop repo is mounted at /vagrant
ls /vagrant
# apps/  docs/  manifests/  scripts/  Vagrantfile  README.md

# 4. The host-only interface has the right IP
ip addr show eth1
# inet 192.168.56.10/24
```

---

## Step 5 — Verify host connectivity

From your **laptop** (not the VM), confirm you can reach the VM's host-only IP:

```bash
ping 192.168.56.10
```

If this times out, check your VirtualBox host-only network adapter:

```bash
# macOS/Linux
VBoxManage list hostonlyifs
# Should show vboxnet0 with IP 192.168.56.1

# Windows
VBoxManage list hostonlyifs
```

If no host-only adapter exists:
```bash
VBoxManage hostonlyif create
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
```

Then re-run `vagrant up`.

---

## Working directory

Inside the VM, the repo is available at `/vagrant` (a VirtualBox shared folder).
All workshop commands are run from `/vagrant`:

```bash
cd /vagrant
```

---

## Stopping and restarting the VM

```bash
vagrant halt       # graceful shutdown (preserves state)
vagrant up         # restart
vagrant suspend    # pause (faster resume, uses disk space)
vagrant resume     # resume from suspend
vagrant destroy    # delete the VM entirely (start fresh)
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `vagrant up` fails: VT-x/AMD-V not enabled | Enable virtualisation in BIOS/UEFI settings |
| `vagrant up` fails: port conflict | Another VM may be using the host-only range; stop it |
| `kubectl get nodes` shows NotReady | k3s is still starting; wait 30–60 s |
| `/vagrant` is empty inside VM | Shared folder issue; try `vagrant reload` |
| Very slow image pulls | Images should be pre-pulled; if not, wait 5–10 min |
