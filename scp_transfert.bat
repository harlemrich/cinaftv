scp -r "C:\Users\user\Desktop\file-server-main" root@31.220.79.175:/root/
scp -r "C:\Users\user\Desktop\file-server-main" root@31.220.79.175:/root/
 cd /root/file-server-main
 rm -rf file-server-main


Ou mieux, pour être sûr que le dossier complet reste intact :
scp -r "C:\Users\user\Desktop\file-server-main" root@31.220.79.175:/root/file-server-main

scp -r "C:\Users\user\Desktop\downloadToS3TransfertToFTP" root@31.220.79.175:/root/downloadToS3TransfertToFTP
C:\Users\user\Desktop\downloadToS3TransfertToFTP


scp -r "Download" root@31.220.79.175:/root/kubeconfig-rancher.yaml

scp -r "C:\Users\user\Downloads\kubeconfig-rancher.yaml" root@31.220.79.175:/root/kubeconfig-rancher.yaml

C:\Users\user\Documents\Cinaf Rancher>scp -r ./k3s root@31.220.79.175:/root/

C:\Users\user\Documents\Cinaf Rancher>scp -r ./install_docker.sh root@31.220.79.175:/root/

scp -r "C:\Users\user\Documents\Cinaf Rancher\deploy" root@31.220.79.175:/root/
