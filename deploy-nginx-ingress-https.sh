#!/bin/bash

set -e

echo ">>> [1/5] Déploiement du NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

echo ">>> Attente des pods Ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pods \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo ">>> [2/5] Installation de Cert Manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo ">>> Attente des pods Cert Manager..."
kubectl wait --namespace cert-manager \
  --for=condition=Ready pods \
  --all \
  --timeout=120s

echo ">>> [3/5] Création du ClusterIssuer (staging Let's Encrypt)..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: richstevecedric@cinaf.tv
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo ">>> [4/5] Déploiement du service NGINX et Ingress sécurisé..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-app
  template:
    metadata:
      labels:
        app: nginx-app
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - nginx.local
    secretName: nginx-local-tls
  rules:
  - host: nginx.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
EOF

echo ">>> [5/5] Mise à jour de /etc/hosts (optionnel)"
read -p "Ajouter nginx.local dans /etc/hosts ? (y/n) : " CHOICE
if [[ "$CHOICE" == "y" ]]; then
  INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [[ -z "$INGRESS_IP" ]] && INGRESS_IP="127.0.0.1"
  echo "$INGRESS_IP nginx.local" | sudo tee -a /etc/hosts
  echo ">>> Entrée ajoutée : $INGRESS_IP nginx.local"
fi

echo ">>> Déploiement terminé. Accède à https://nginx.local (il est normal que le certificat de staging soit non fiable dans le navigateur)."
