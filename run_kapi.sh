#!/bin/bash

# === CONFIGURATION ===
SERVER_USER="root"
SERVER_IP="31.220.79.175"
SERVER_PASS="tJHw5NA+77"
LOCAL_FOLDER="./kapi"
REMOTE_FOLDER="/root/kapi"
SCRIPT_NAME="api.sh"

# === VÉRIFIE QUE sshpass EST INSTALLÉ ===
if ! command -v sshpass &> /dev/null; then
    echo "[ERREUR] sshpass n'est pas installé. Installe-le avec : sudo apt install sshpass -y"
    exit 1
fi

# === VÉRIFIE LE DOSSIER LOCAL EXISTE ===
if [ ! -d "$LOCAL_FOLDER" ]; then
    echo "[ERREUR] Dossier local $LOCAL_FOLDER introuvable."
    exit 1
fi

# === TRANSFERT DU DOSSIER VERS LE SERVEUR ===
echo "[+] Transfert de $LOCAL_FOLDER vers $SERVER_USER@$SERVER_IP:$REMOTE_FOLDER ..."
sshpass -p "$SERVER_PASS" scp -r "$LOCAL_FOLDER" "$SERVER_USER@$SERVER_IP:/root/"

# === EXECUTION DU SCRIPT DISTANT ===
echo "[+] Connexion à $SERVER_IP et exécution de $SCRIPT_NAME ..."
sshpass -p "$SERVER_PASS" ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" \
"chmod +x $REMOTE_FOLDER/$SCRIPT_NAME && dos2unix $REMOTE_FOLDER/$SCRIPT_NAME && bash $REMOTE_FOLDER/$SCRIPT_NAME"
