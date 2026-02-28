# -*- mode: ruby -*-
# vi: set ft=ruby :

# ops-demo Vagrantfile
# Provisions Ubuntu 24.04 + k3s (no traefik, no servicelb) + Helm + Git
# Two network adapters:
#   Adapter 1: NAT (internet access)
#   Adapter 2: Host-only 192.168.56.x (MetalLB L2 — reachable from laptop)

VAGRANTFILE_API_VERSION = "2"

VM_NAME     = "ops-demo"
VM_CPUS     = 4
VM_MEMORY   = 8192   # 8 GB — ArgoCD + Tekton need headroom
HOST_ONLY_IP = "192.168.56.10"

# k3s version — pin so the workshop is reproducible
K3S_VERSION = "v1.31.4+k3s1"

$provision = <<-SHELL
  set -euxo pipefail

  export DEBIAN_FRONTEND=noninteractive

  # ── 1. System packages ─────────────────────────────────────────────────────
  apt-get update -qq
  apt-get install -y -qq \
    curl git jq unzip bash-completion

  # ── 2. k3s ─────────────────────────────────────────────────────────────────
  # Disable traefik and the built-in service-lb so MetalLB can take over.
  # Bind to the host-only interface so ArgoCD LB IP is reachable from the host.
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="#{K3S_VERSION}" \
    K3S_KUBECONFIG_MODE="644" \
    sh -s - server \
      --disable=traefik \
      --disable=servicelb \
      --node-ip=#{HOST_ONLY_IP} \
      --advertise-address=#{HOST_ONLY_IP}

  # Wait for k3s to be ready
  until kubectl get nodes 2>/dev/null | grep -q ' Ready'; do
    echo "Waiting for k3s node to be ready..."
    sleep 5
  done
  echo "k3s is ready."

  # ── 3. kubeconfig for vagrant user ─────────────────────────────────────────
  mkdir -p /home/vagrant/.kube
  cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
  # Point server to host-only IP so it works outside the VM too
  sed -i "s|127.0.0.1|#{HOST_ONLY_IP}|g" /home/vagrant/.kube/config
  chown -R vagrant:vagrant /home/vagrant/.kube

  # Also export KUBECONFIG in .bashrc
  echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc
  echo 'source <(kubectl completion bash)' >> /home/vagrant/.bashrc
  echo 'alias k=kubectl' >> /home/vagrant/.bashrc
  echo 'complete -o default -F __start_kubectl k' >> /home/vagrant/.bashrc

  # ── 4. Helm ────────────────────────────────────────────────────────────────
  HELM_VERSION="v3.16.4"
  curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
    DESIRED_VERSION="${HELM_VERSION}" bash
  echo 'source <(helm completion bash)' >> /home/vagrant/.bashrc

  # ── 5. yq (used by Tekton bump-image-tag task) ─────────────────────────────
  YQ_VERSION="v4.44.3"
  ARCH=$(dpkg --print-architecture)   # amd64 or arm64
  curl -sSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" \
    -o /usr/local/bin/yq
  chmod +x /usr/local/bin/yq

  # ── 6. Pre-pull key images (offline resilience) ────────────────────────────
  # k3s uses containerd; pull via ctr
  export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
  export CONTAINERD_NAMESPACE=k8s.io

  images=(
    "quay.io/argoproj/argocd:v2.13.3"
    "ghcr.io/stefanprodan/podinfo:6.6.2"
    "ghcr.io/stefanprodan/podinfo:6.7.0"
    "quay.io/metallb/controller:v0.14.9"
    "quay.io/metallb/speaker:v0.14.9"
    "registry.k8s.io/ingress-nginx/controller:v1.12.0"
    "ghcr.io/tektoncd/pipeline/controller-10a3e32792f33651396d02b6855a6e36:v0.65.1"
    "ghcr.io/tektoncd/pipeline/webhook-d4749e605405422fd87700164e31b2d1:v0.65.1"
    "ghcr.io/tektoncd/pipeline/resolvers-ff86b24f130c42b88983d3c13993056d:v0.65.1"
    "docker.io/alpine/git:latest"
    "docker.io/mikefarah/yq:4.44.3"
  )

  for img in "${images[@]}"; do
    echo "Pre-pulling: ${img}"
    k3s ctr images pull "${img}" || echo "WARNING: failed to pull ${img} (will retry at runtime)"
  done

  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "  VM provisioned successfully!"
  echo "  SSH:       vagrant ssh"
  echo "  Next step: follow docs/vm-setup.md to verify, then"
  echo "             run scripts/bootstrap.sh to install ArgoCD"
  echo "════════════════════════════════════════════════════════"
SHELL

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box     = "bento/ubuntu-24.04"
  config.vm.box_version = "~> 202502"    # pin major release; allows patch updates
  config.vm.hostname = VM_NAME

  # Adapter 2: host-only so MetalLB IPs are reachable from the laptop
  config.vm.network "private_network", ip: HOST_ONLY_IP

  # Sync the repo into /vagrant (default) — participants work inside the VM
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = VM_NAME
    vb.cpus   = VM_CPUS
    vb.memory = VM_MEMORY
    # Needed for nested networking
    vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
  end

  config.vm.provision "shell", inline: $provision, privileged: true
end
