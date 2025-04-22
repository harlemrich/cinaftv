#!/bin/bash

set -e
# === CONFIGURATION ===
NAMESPACE="my-app-cinaf"
DEPLOYMENT_NAME="my-api-cinaf2"
SERVICE_NAME="api-service-cinaf"
INGRESS_NAME="api-ingress-cinaf"
IMAGE_NAME="nginxdemos/hello"  # Remplace par ton image Docker
DOMAIN_NAME="api.rancher.cinaf.tv"  # Remplace par ton domaine réel
PORT=80
EMAIL="richstevecedric@cinaf.tv"          # Remplace par ton adresse mail pour Let's Encrypt

# === PRÉREQUIS ===
echo "[1/7] Création du namespace : $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

echo "[2/7] Création du ClusterIssuer Let's Encrypt"
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: $EMAIL
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo "[3/7] Déploiement de l'application : $DEPLOYMENT_NAME"
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $DEPLOYMENT_NAME
  template:
    metadata:
      labels:
        app: $DEPLOYMENT_NAME
    spec:
      containers:
      - name: api
        image: $IMAGE_NAME
        ports:
        - containerPort: $PORT
EOF

echo "[4/7] Création du service : $SERVICE_NAME"
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: Service
metadata:
  name: $SERVICE_NAME
spec:
  selector:
    app: $DEPLOYMENT_NAME
  ports:
  - protocol: TCP
    port: 80
    targetPort: $PORT
EOF

echo "[5/7] Création de la ressource Certificate"
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${DOMAIN_NAME//./-}-tls
spec:
  secretName: ${DOMAIN_NAME//./-}-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: $DOMAIN_NAME
  dnsNames:
  - $DOMAIN_NAME
EOF

echo "[6/7] Création de l'Ingress avec TLS"
cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $INGRESS_NAME
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - $DOMAIN_NAME
    secretName: ${DOMAIN_NAME//./-}-tls
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SERVICE_NAME
            port:
              number: 80
EOF

echo "[7/7] 🎉 Déploiement terminé. Accès à : https://$DOMAIN_NAME"
