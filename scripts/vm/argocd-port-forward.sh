#!/usr/bin/env bash
set -euo pipefail

export KUBECONFIG=/home/vagrant/.kube/config
exec kubectl -n argocd port-forward svc/argocd-server 8080:443 --address 127.0.0.1
