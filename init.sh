#!/bin/bash

set -e
# 1. Mise à jour du système
apt update && apt upgrade -y

# 2. Installer curl (si ce n’est pas déjà fait)
apt install curl -y

# -------------------------
# Script global multi_server_monitoring.sh avec K3s + Rancher + NGINX + CertManager + Let's Encrypt
# -------------------------

# 3. Installation sécurisée de K3s si non présent
if ! command -v k3s &> /dev/null && ! systemctl is-active --quiet k3s; then
  echo "🚀 Installation de K3s (Kubernetes léger)..."
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
else
  echo "✅ K3s est déjà installé et actif."
fi

# 4. Configuration du pare-feu (UFW)
sudo apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 6443/tcp       # API server
sudo ufw allow 8472/udp       # Flannel (VXLAN)
sudo ufw allow 10250/tcp      # Kubelet
sudo ufw allow 30000:32767/tcp  # NodePort si utilisé
sudo ufw allow 80/tcp    # HTTP pour Let's Encrypt (ACME)
sudo ufw allow 443/tcp   # HTTPS pour Rancher
sudo ufw enable

# 5. Accès API sécurisé
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# 6. Installe Helm si absent
if ! command -v helm &> /dev/null; then
  echo "🚀 Installation de Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm est déjà installé."
fi

# 7. Installer NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.publishService.enabled=true

# 8. Activer HTTPS avec cert-manager (pour Rancher)
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true
sleep 10
kubectl apply -f letsencrypt-prod.yaml

# 8. Installer Rancher (avec HTTPS via Let's Encrypt)
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
helm install rancher rancher-latest/rancher \
  --namespace cattle-system --create-namespace \
  --set bootstrapPassword=admin \
  --set ingress.enabled=false
sleep 10
kubectl apply -f rancher-ingress.yaml