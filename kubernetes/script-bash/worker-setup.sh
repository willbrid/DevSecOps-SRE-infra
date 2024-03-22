#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour ajouter des noeuds worker au 
#   cluster Kubernetes sur une machine vagrant Rocky linux 8.
#
# Utilisation :
#   sudo ./worker-setup.sh

# Initialisation des variables
joinfile="/home/vagrant/shared/join-command.sh"

# Vérification de l'exécution en mode root
checkIfRoot() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Vérification de la présence des packages kubeadm, kubelet, kubectl et containerd
checkDependency() {
    if ! command -v kubeadm &> /dev/null || ! command -v kubelet &> /dev/null || ! command -v kubectl || ! command -v containerd &> /dev/null; then
        echo "Veuillez installer les packages kubeadm, kubelet, kubectl et containerd pour exécuter ce script. Veuillez utiliser le script common-setup.sh"
        exit 1
    fi
}

# Vérification de la présence du script d'ajout d'un noeud worker au cluster
checkJoinCommand() {
    if [ ! -f "$joinfile" ]; then
        echo "Veuillez initier d'abord le cluster via le script master-setup.sh depuis le noeud master."
        exit 1
    fi
}

# Ajout du noeud au cluster kubernetes
joinWorkerToCluster() {
    echo -e "\nAjout du noeud dans le cluster en cours...\n"
    
    firewall-cmd --permanent --add-port={10250,30000-32767}/tcp
    firewall-cmd --reload

    joincommand=$(<"$joinfile")
    eval "$joincommand"

    echo -e "\nAjout du noeud dans le cluster : OK\n"
}

# failTrap est exécuté si une erreur se produit.
failTrap() {
    result=$?
    
    if [ "$result" != "0" ]; then
        echo -e "\tEchec d'ajout du noeud worker au cluster kubernetes."
    fi
    
    exit $result
}


# Execution

# Arrêter l'exécution en cas d'erreur
trap "failTrap" EXIT
set -e

checkIfRoot
checkDependency
checkJoinCommand
joinWorkerToCluster

echo -e "\nConfiguration du noeud worker : OK\n"