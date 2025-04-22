#!/bin/bash

# === CONFIGURATION ===
SERVER_USER="root"
SERVER_IP="31.220.79.175"
SERVER_PASS="tJHw5NA+77"
LOCAL_FOLDER="./k3s"
REMOTE_FOLDER="/root/k3s"
SCRIPT_NAME="init.sh"

# === VÉRIFIE LE DOSSIER LOCAL EXISTE ===
if [ ! -d "$LOCAL_FOLDER" ]; then
    echo "[ERREUR] Dossier local $LOCAL_FOLDER introuvable."
    exit 1
fi

# === TRANSFERT DU DOSSIER VERS LE SERVEUR ===
echo "[+] Transfert de $LOCAL_FOLDER vers $SERVER_USER@$SERVER_IP:$REMOTE_FOLDER ..."
scp -r "$LOCAL_FOLDER" "$SERVER_USER@$SERVER_IP:/root/"

# === EXECUTION DU SCRIPT DISTANT ===
echo "[+] Connexion à $SERVER_IP et exécution de $SCRIPT_NAME ..."
ssh "$SERVER_USER@$SERVER_IP" "cd $REMOTE_FOLDER && chmod +x ./$SCRIPT_NAME && sed -i 's/\r$//' ./$SCRIPT_NAME && ./$SCRIPT_NAME"
