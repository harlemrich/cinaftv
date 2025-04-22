#!/bin/bash

set -e

# -------------------------
# Script global multi_server_monitoring.sh avec K3s + Rancher + NGINX + CertManager + Let's Encrypt
# -------------------------

# 1. Vérifie et installe Docker si absent
if ! command -v docker &> /dev/null; then
  echo "🚀 Docker non trouvé, installation en cours..."
  curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
else
  echo "✅ Docker est déjà installé."
fi

# 2. Installe K3s si non présent
if ! command -v k3s &> /dev/null && ! systemctl is-active --quiet k3s; then
  echo "🚀 Installation de K3s (Kubernetes léger)..."
  curl -sfL https://get.k3s.io | sh -
else
  echo "✅ K3s est déjà installé et actif."
fi

# 3. Vérifie la disponibilité de kubectl
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl non disponible, vérifiez l'installation de K3s."
  exit 1
fi

# 4. Installe Helm si absent
if ! command -v helm &> /dev/null; then
  echo "🚀 Installation de Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm est déjà installé."
fi

# 5. Installe jq si absent
if ! command -v jq &> /dev/null; then
  echo "🚀 Installation de jq..."
  apt-get update && apt-get install -y jq
else
  echo "✅ jq est déjà installé."
fi

# 5bis. Prépare accès K3s (nécessaire pour kubectl)
if [ ! -f /etc/rancher/k3s/k3s.yaml ]; then
  echo "❌ Fichier /etc/rancher/k3s/k3s.yaml introuvable."
  exit 1
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
chmod 600 /etc/rancher/k3s/k3s.yaml

# 6. Attente de l'API K3s (max 60s)
echo "⏳ Attente de l'API K3s..."
for i in {1..30}; do
  if kubectl get nodes &> /dev/null; then
    echo "✅ API K3s disponible."
    break
  fi
  sleep 2
  if [ $i -eq 30 ]; then
    echo "❌ Échec : API K3s indisponible."
    exit 1
  fi
done

# 7. Installation NGINX Ingress Controller
echo "🚀 Installation de NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml --validate=false || { echo "❌ Échec installation NGINX"; exit 1; }

# Attente que les pods ingress-nginx soient prêts
echo "⏳ Attente que les pods ingress-nginx soient prêts (2 min max)..."
kubectl -n ingress-nginx wait --for=condition=Available deploy/ingress-nginx-controller --timeout=120s || { echo "❌ Les pods ingress-nginx ne sont pas prêts"; exit 1; }

# 8. Installation Cert Manager
echo "🚀 Installation de Cert Manager..."
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml || { echo "❌ Échec installation Cert Manager"; exit 1; }

# 9. Attente que les pods cert-manager soient prêts
echo "⏳ Attente des pods Cert Manager (3 min max)..."
kubectl -n cert-manager wait deployment --all --for=condition=available --timeout=180s || { echo "❌ Cert Manager ne démarre pas"; exit 1; }

# 10. Création du ClusterIssuer Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-http
spec:
  acme:
    email: richstevecedric@cinaf.tv
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-http-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 11. Déploiement Rancher via Helm sur K3s
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo update
kubectl create namespace cattle-system || true

# 🔁 Supprime l'installation précédente de Rancher si elle existe
if helm ls -n cattle-system | grep -q '^rancher'; then
  echo "🔁 Rancher déjà installé, suppression de l'ancienne installation..."
  helm uninstall rancher -n cattle-system || true
  kubectl delete job -n cattle-system rancher-post-delete || true
  sleep 10
fi

helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.cluster.cinaf.tv \
  --set replicas=1 \
  --set ingress.tls.source=letsEncrypt \
  --set ingress.ingressClassName=nginx || { echo "❌ Échec installation Rancher"; exit 1; }

# 12. Attente Rancher prêt
echo "⏳ Attente que Rancher soit prêt (5 min max)..."
kubectl -n cattle-system rollout status deploy/rancher --timeout=300s || { echo "❌ Rancher ne démarre pas"; exit 1; }

# 13. Bootstrap Rancher pour récupérer kubeconfig
RANCHER_URL="https://rancher.cluster.cinaf.tv"

if [ -z "$RANCHER_ADMIN_PASSWORD" ]; then
  echo -n "🔐 Entrez le mot de passe admin pour Rancher : "
  read -s ADMIN_PASSWORD
  echo
else
  ADMIN_PASSWORD="7LQUOt3Jwf4HNldN"
fi

for i in {1..60}; do
  if curl -sk "$RANCHER_URL" | grep -q "Rancher"; then
    echo "✅ Interface Rancher disponible."
    break
  fi
  sleep 5
  if [ $i -eq 60 ]; then
    echo "❌ Rancher ne répond pas à l'URL $RANCHER_URL"
    exit 1
  fi
done

LOGIN_TOKEN=$(curl -sk "$RANCHER_URL/v3-public/localProviders/local?action=login" \
  -H 'Content-Type: application/json' \
  --data-binary '{"username":"admin","password":"'$ADMIN_PASSWORD'"}' | jq -r .token)

API_TOKEN=$(curl -sk "$RANCHER_URL/v3/token" \
  -H "Authorization: Bearer $LOGIN_TOKEN" \
  -H 'Content-Type: application/json' \
  --data-binary '{"type":"token","description":"automation"}' | jq -r .token)

curl -sk "$RANCHER_URL/v3/clusters/local?action=generateKubeconfig" \
  -H "Authorization: Bearer $API_TOKEN" \
  -X POST | jq -r .config > /root/kubeconfig-rancher.yaml
chmod 600 /root/kubeconfig-rancher.yaml

# 14. kubeconfig local shell config
KUBECONFIG_PATH="/root/kubeconfig-rancher.yaml"
SHELL_RC="$HOME/.bashrc"
if [[ "$SHELL" == */zsh ]]; then
  SHELL_RC="$HOME/.zshrc"
fi

if ! grep -q "export KUBECONFIG=$KUBECONFIG_PATH" "$SHELL_RC"; then
  echo "export KUBECONFIG=$KUBECONFIG_PATH" >> "$SHELL_RC"
  echo "✅ Variable d'environnement KUBECONFIG ajoutée à $SHELL_RC"
fi
export KUBECONFIG=$KUBECONFIG_PATH

# 15. Test final
echo "🔍 Test de connexion au cluster avec kubectl..."
kubectl get nodes || { echo "⚠️ Problème avec le fichier kubeconfig."; exit 1; }

# 16. Fin
echo "🎉 Stack Rancher sur K3s avec NGINX, CertManager, Let's Encrypt et bootstrap Rancher prête."

# Astuce temporaire (non recommandé en production) :
# kubectl --insecure-skip-tls-verify=true get pods -A
