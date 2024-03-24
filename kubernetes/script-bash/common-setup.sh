#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour configurer un environnement de 
#   cluster Kubernetes sur une machine Rocky linux 8. Il effectue plusieurs tâches 
#   essentielles, notamment l'ajout d'une règle masquerade au pare-feu, la Configuration
#   de selinux en mode permissive, la désactivation du swap, l'activation du routage, 
#   la configuration des modules kernel (overlay et br_netfilter) pour containerd, ainsi que 
#   l'installation des packages nécessaires pour containerd, runc kubeadm, kubelet et kubectl.
#
# Utilisation :
#   sudo ./common-setup.sh [options]
#
# Options :
#   -h, --help              Afficher cette aide
#   --hostname              Nom d'hôte à configurer
#   --hostfile              Fichier d'hôtes
#   --k8s-version           Version de Kubernetes
#   --containerd-version    Version de containerd (Par défaut: 1.7.13)"

# Initialisation des variables
hostname=""
hostfile=""
k8sVersion=""
repok8sVersion=""
k8sPathSetting=""
containerdVersion="1.7.13"
CONTAINERD_TMP=""

# Vérification de l'exécution en mode root
checkIfRoot() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Définition de la fonction d'aide
displayHelp() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  --hostname              Nom d'hôte à configurer"
    echo "  --hostfile              Fichier d'hôtes"
    echo "  --k8s-version           Version de Kubernetes"
    echo "  --containerd-version    Version de containerd (Par défaut: 1.7.13)"
}

# Vérification des options entrées
verifyOptions() {
    if [[ -z $hostname ]] || [[ -z $hostfile ]] || [[ -z $k8sVersion ]]; then
        echo "Les options --hostname, --hostfile et --k8s-version sont obligatoires."
        displayHelp
        exit 1
    fi

    if [ ! -f "$hostfile" ]; then
        echo "Le fichier de configuration $hostfile n'existe pas."
        exit 1
    fi

    validationk8sVersion="^[0-9]+\.[0-9]+\.[0-9]+$"
    if ! [[ $k8sVersion =~ $validationk8sVersion ]]; then
        echo "Erreur: $k8sVersion n'est pas sous le format x.y.z où x, y et z sont des nombres."
        exit 1
    fi
}

# Configuration du système
setupSystem() {
    echo -e "\nConfiguration du système en cours...\n"

    # Configuration du hostname du serveur
    hostnamectl set-hostname $hostname

    while read -r ip host; do
        echo -e "$ip\t$host" >> /etc/hosts
    done < "$hostfile"

    setenforce 0
    sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

    echo -e "\n----Ajout d'une règle masquerade NAT----\n"

    firewall-cmd --add-masquerade --permanent
    firewall-cmd --reload

    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    cat << EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
    modprobe overlay
    modprobe br_netfilter

    cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
    sysctl --system

    echo -e "\nConfiguration du système : OK\n"
}

# Configuration de containerd
setupContainerd() {
    echo -e "\nInstallation et configuration de containerd en cours...\n"

    mkdir -p /usr/local/bin

    k8sPathSetting="/etc/profile.d/usr_local_bin_path_setting.sh"
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' > $k8sPathSetting
    fi
    if [ -f "$k8sPathSetting" ]; then
        source $k8sPathSetting
    fi

    CONTAINERD_TMP="$(mktemp -dt containerd-installer-XXXXXXX)"

    wget -q -P $CONTAINERD_TMP https://github.com/containerd/containerd/releases/download/v$containerdVersion/containerd-$containerdVersion-linux-amd64.tar.gz 2>&1
    tar Czxvf $CONTAINERD_TMP $CONTAINERD_TMP/containerd-$containerdVersion-linux-amd64.tar.gz
    mv $CONTAINERD_TMP/bin/* /usr/local/bin/

    wget -q -P $CONTAINERD_TMP https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 2>&1
    mv "$CONTAINERD_TMP/containerd.service" /usr/lib/systemd/system/
    chown root:root /usr/lib/systemd/system/containerd.service
    restorecon /usr/lib/systemd/system/containerd.service
    systemctl daemon-reload
    systemctl enable --now containerd

    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    systemctl restart containerd

    echo -e "\nInstallation et configuration de containerd : OK\n"
}

# Installation des packages du nfs client
setupNFSClient() {
    echo -e "\nInstallation du client NFS en cours...\n"

    dnf -q install -y nfs-utils nfs4-acl-tools

    echo -e "\nInstallation du client NFS : OK\n"
}

# Installation des packages de kubernetes
setupKubernetes() {
    echo -e "\nInstallation de kubernetes en cours...\n"

    repok8sVersion="${k8sVersion%.*}"
    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$repok8sVersion/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$repok8sVersion/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    dnf -q install -y kubelet-$k8sVersion kubeadm-$k8sVersion kubectl-$k8sVersion --disableexcludes=kubernetes
    systemctl enable --now kubelet

    cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: true
EOF
    echo -e "\nInstallation de kubernetes : OK\n"
}

# Nettoyage du répertoire temporaire d'installation de containerd
cleanup() {
  if [[ -d "${CONTAINERD_TMP:-}" ]]; then
    rm -rf "$CONTAINERD_TMP"
  fi
}

# failTrap est exécuté si une erreur se produit.
failTrap() {
    result=$?

    if [ "$result" != "0" ]; then
        echo -e "\tEchec de préparation du noeud du cluster kubernetes."
    fi
    
    cleanup
    exit $result
}


# Execution

# Arrêter l'exécution en cas d'erreur
trap "failTrap" EXIT
set -e

checkIfRoot

# Traitement des options avec getopts
while getopts ":h-:" opt; do
    case ${opt} in
        h)
          displayHelp
          exit 0
          ;;
        -)
            case "${OPTARG}" in
                hostname=*)
                  hostname="${OPTARG#*=}"
                  ;;
                hostfile=*)
                  hostfile="${OPTARG#*=}"
                  ;;
                k8s-version=*)
                  k8sVersion="${OPTARG#*=}"
                  ;;
                containerd-version=*)
                  containerdVersion="${OPTARG#*=}"
                  ;;
                help)
                  displayHelp
                  exit 0
                  ;;
                *)
                  echo "Option invalide: --${OPTARG}"
                  exit 1
                  ;;
            esac
            ;;
        \?)
            echo "Option invalide: -$OPTARG" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

verifyOptions
setupSystem
setupContainerd
setupNFSClient
setupKubernetes
cleanup

echo -e "\nConfiguration de base : OK\n"