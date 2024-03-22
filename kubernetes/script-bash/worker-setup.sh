#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour ajouter des noeuds worker au 
#   cluster Kubernetes sur une machine vagrant Rocky linux 8.
#
# Utilisation :
#   sudo ./worker-setup.sh

# Vérification de l'exécution en mode root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Initialisation des variables
joinfile="/home/vagrant/shared/join-command.sh"

# Vérification de la présence du script d'ajout d'un noeud worker
if [ ! -f "$joinfile" ]; then
    echo "Veuillez initier d'abord le cluster via le script mastersetup.sh !"
    exit 1
fi

# Vérification de la présence des packages kubeadm, kubelet et kubectl
if ! command -v kubeadm &> /dev/null || ! command -v kubelet &> /dev/null || ! command -v kubectl &> /dev/null; then
    echo "Veuillez installer les packages kubeadm, kubelet et kubectl pour exécuter ce script. Veuillez utiliser le script initialsetup.sh"
    exit 1
fi


echo -e "\n----Autorisation des ports par défaut des composants du noeud worker----\n"

firewall-cmd --permanent --add-port={10250,30000-32767}/tcp
firewall-cmd --reload


echo -e "\n----Ajout du noeud dans le cluster----\n"

joincommand=$(<"$joinfile")
eval "$joincommand"


echo -e "\n----Configuration du noeud worker avec succès----\n"