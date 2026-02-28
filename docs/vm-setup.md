# VM-setup

Alles draait in een VirtualBox-VM die Vagrant voor je opzet. Volg deze stappen voordat je aan de oefeningen begint.

---

## Wat je nodig hebt

Doe dit de dag ervoor — niet op de ochtend van de workshop zelf.

| Tool       | Versie      | Download                                          | Of op Mac                 |
|------------|-------------|---------------------------------------------------|---------------------------|
| VirtualBox | 7.x         | https://www.virtualbox.org/wiki/Downloads         | `brew install virtualbox` |
| Vagrant    | 2.4.x       | https://developer.hashicorp.com/vagrant/downloads | `brew install vagrant`    |
| Git        | willekeurig | https://git-scm.com/downloads                     |                           |

Minimaal 12 GB vrij RAM, ~15 GB schijfruimte.

**Na installatie van VirtualBox: herstart je laptop.** VirtualBox installeert een kernel-extensie en die werkt pas na
een reboot.

Snelle check — alle drie moeten een versie tonen:

> **VM**
> ```bash
> VBoxManage --version && vagrant --version && git --version
> ```

---

## Stap 1 — Fork en clone de repo

Fork de repo naar je eigen GitHub-account via https://github.com/paulharkink/ops-demo → **Fork**.

> **HOST**
> ```bash
> git clone https://github.com/JOUW_USERNAME/ops-demo.git
> cd ops-demo
> ```

---

## Stap 2 — VM opstarten

> **VM**
> ```bash
> vagrant up
> ```

De eerste keer duurt dit 10–15 minuten. Vagrant downloadt de Ubuntu 24.04 box, installeert k3s, Helm en yq, en haalt de
workshop-images alvast op. Daarna start de VM in een paar seconden.

Aan het einde zie je:

```
════════════════════════════════════════════════════════
  VM provisioned successfully!
════════════════════════════════════════════════════════
```

---

## Stap 3 — Inloggen

> **HOST**
> ```bash
> vagrant ssh
> cd /vagrant
> ```

Alle workshop-commando's voer je vanaf hier uit, tenzij anders aangegeven.

---

## Stap 4 — Controleer de setup

> **VM**
> ```bash
> kubectl get nodes
> # NAME       STATUS   ROLES                  AGE   VERSION
> # ops-demo   Ready    control-plane,master   Xm    v1.31.x+k3s1
>
> helm version
> # version.BuildInfo{Version:"v3.16.x", ...}
>
> ls /vagrant
> # Vagrantfile  README.md  apps/  docs/  manifests/  scripts/
> ```

---

## Stap 5 — Controleer bereikbaarheid vanaf je laptop

Vanuit je laptop (niet de VM):

> **VM**
> ```bash
> ping 192.168.56.10
> ```

Werkt dit niet, controleer dan of de VirtualBox host-only adapter bestaat:

> **VM**
> ```bash
> VBoxManage list hostonlyifs
> # Verwacht: vboxnet0 met IP 192.168.56.1
> ```

Bestaat hij niet:

> **VM**
> ```bash
> VBoxManage hostonlyif create
> VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
> ```

Dan `vagrant up` opnieuw.

---

## Handige Vagrant-commando's

> **VM**
> ```bash
> vagrant halt       # afsluiten
> vagrant up         # opstarten
> vagrant suspend    # pauzeren
> vagrant resume     # hervatten
> vagrant destroy    # VM volledig verwijderen
> ```

---

## Probleemoplossing

| Symptoom                       | Oplossing                                             |
|--------------------------------|-------------------------------------------------------|
| "No usable default provider"   | VirtualBox niet geïnstalleerd of laptop niet herstart |
| VT-x/AMD-V niet beschikbaar    | Schakel virtualisatie in via BIOS/UEFI                |
| `kubectl get nodes` → NotReady | k3s start nog op, wacht 30–60 seconden                |
| `/vagrant` is leeg             | Shared folder probleem — probeer `vagrant reload`     |
