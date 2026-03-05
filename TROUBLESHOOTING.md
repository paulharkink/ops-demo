# Troubleshooting

## Veelvoorkomende problemen

### Apple Silicon: VM start niet (`arm64` vs `amd64`)

- Check host + box-architectuur: `uname -m` en `vagrant box list`.
- Op Apple Silicon moet de box `arm64` zijn.
- Forceer opnieuw:
  `vagrant box remove bento/ubuntu-24.04 --provider virtualbox`
  en daarna:
  `vagrant box add bento/ubuntu-24.04 --provider virtualbox --architecture arm64`.
- Gebruik bij voorkeur de officiële VirtualBox Apple Silicon installer.

### Windows: `vagrant up` blijft hangen op netwerk/adapter

- Dit is meestal een Host-Only adapter race/driver issue.
- Probeer `vagrant up` eerst 1-2 keer opnieuw.
- Blijft het hangen: check `VBoxManage list hostonlyifs`.
- Als er geen actieve adapter is: open VirtualBox GUI eenmalig als
  Administrator en laat de VM 1x starten.
- Helpt dat niet: herstel de VirtualBox network drivers
  (Host-Only/NDIS) en probeer opnieuw.

### `A VirtualBox machine with the name 'ops-demo' already exists`

- Je hebt waarschijnlijk twee repo-kopieen met dezelfde VM-naam.
- Check `vagrant global-status --prune`.
- Stop/destroy de andere omgeving, of geef een unieke VM-naam in een van de
  `Vagrantfile`s.

### `vagrant up` faalt maar `vagrant status` zegt `poweroff`

- Je zit mogelijk in een andere repo-map dan de VM die nu draait.
- Controleer de `directory` kolom in `vagrant global-status --prune`.

### Ik weet het ArgoCD admin-wachtwoord niet (meer)

- Lees het opnieuw uit:
  ```bash
  vagrant ssh -c "export KUBECONFIG=/home/vagrant/.kube/config; \
  kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d"
  ```

### Ik kan niet inloggen met `vagrant ssh`

- Controleer eerst of je in de juiste repo-map staat (`pwd`) en run
  `vagrant status`.
- Als de VM niet draait: `vagrant up`.
- Helpt dat niet: `vagrant global-status --prune` en check de `directory`.

### ArgoCD UI niet bereikbaar op `http://localhost:8080`

- Start de tunnel opnieuw:
  `./scripts/host/argocd-ui-tunnel.sh` (of `.ps1` op Windows).

### `kubectl` lijkt naar de verkeerde cluster te wijzen

- Gebruik de host-scripts:
  `./scripts/host/bootstrap-from-host.sh` en
  `./scripts/host/argocd-ui-tunnel.sh`.
- Of log in met `vagrant ssh` en werk vanuit `/vagrant`.
- De bootstrap heeft cluster-checks en stopt bij mismatch.

### `root` app blijft `Unknown` of `OutOfSync`

- Controleer of `apps/root.yaml` naar jouw fork verwijst.
- Controleer dat je commit/push hebt gedaan.
- Klik daarna in ArgoCD op **Refresh**.

### Tekton pipeline kan niet pushen naar GitHub

- Zet credentials opnieuw:
  in VM:
  `./scripts/vm/set-git-credentials.sh <github-user> <github-pat>`
  (na `vagrant ssh` + `cd /vagrant`).
- Of vanaf host:
  `vagrant ssh -c "/vagrant/scripts/vm/set-git-credentials.sh <github-user> <github-pat>"`.
- Gebruik een PAT met juiste repo-rechten.

### MetalLB/Ingress hostnames werken niet

- Wacht tot networking apps `Healthy` zijn in ArgoCD.
- Controleer of host-only netwerk `192.168.56.x` actief is.
