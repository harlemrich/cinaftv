#!/bin/bash

chmod +x install_docker.sh

# Mise à jour des paquets
echo "Mise à jour des paquets..."
sudo apt-get update -y

# Installation de Docker
echo "Installation de Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh

# Vérification de l'installation de Docker
echo "Vérification de l'installation de Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Vérification si Docker est démarré
echo "Vérification du statut de Docker..."
docker_status=$(sudo systemctl is-active docker)

if [ "$docker_status" == "active" ]; then
    echo "Docker est en cours d'exécution."
else
    echo "Docker n'est pas en cours d'exécution. Tentative de démarrage..."
    sudo systemctl start docker
    docker_status=$(sudo systemctl is-active docker)
    if [ "$docker_status" == "active" ]; then
        echo "Docker a été démarré avec succès."
    else
        echo "Échec du démarrage de Docker."
    fi
fi

# Affichage de l'état du service Docker
echo "Statut de Docker :"
sudo systemctl status docker --no-pager
