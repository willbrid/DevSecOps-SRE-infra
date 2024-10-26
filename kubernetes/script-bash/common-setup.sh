#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour configurer un environnement de 
#   cluster Kubernetes sur une machine Rocky linux 8. Il effectue plusieurs tâches 
#   essentielles, notamment l'ajout d'une règle masquerade au pare-feu, la Configuration
#   de selinux en mode permissive, la désactivation du swap, l'activation du routage, 
#   la configuration du module kernel br_netfilter pour cri-o, ainsi que 
#   l'installation des packages nécessaires pour cri-o, kubeadm, kubelet et kubectl.
#
# Utilisation :
#   sudo ./common-setup.sh [options]
#
# Options :
#   -h, --help              Afficher cette aide
#   --hostfile              Fichier d'hôtes
#   --k8s-version           Version de Kubernetes

# Initialisation des variables
hostfile=""
k8s_version=""

readonly VALIDATION_K8S_VERSION="^[0-9]+\.[0-9]+\.[0-9]+$"
readonly HAS_CURL="$(type "curl" &> /dev/null && echo true || echo false)"
readonly HAS_WGET="$(type "wget" &> /dev/null && echo true || echo false)"

# Vérification de l'exécution en mode root
check_if_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ce script doit être exécuté en tant que root."
        exit 1
    fi
}

# Définition de la fonction d'aide
display_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  --hostfile              Fichier d'hôtes"
    echo "  --k8s-version           Version de Kubernetes"
}

check_dependency() {
    if [ "$HAS_CURL" != "true" ] && [ "$HAS_WGET" != "true" ] ; then
        echo "Erreur: veuillez installer curl ou wget."
        exit 1
    fi
}

# Vérification des options entrées
verify_options() {
    if [ ! -f "$hostfile" ]; then
        echo "Le fichier de configuration $hostfile n'existe pas."
        exit 1
    fi

    if ! [[ $k8s_version =~ $VALIDATION_K8S_VERSION ]]; then
        echo "Erreur: $k8s_version n'est pas sous le format x.y.z où x, y et z sont des nombres."
        exit 1
    fi
}

# Configuration du système
setup_system() {
    # Configuration de toutes les machines du cluster dans le fichier /etc/hosts
    while read -r ip host; do
        echo -e "$ip\t$host" >> /etc/hosts
    done < "$hostfile"

    setenforce 0
    sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

    firewall-cmd --add-masquerade --permanent
    firewall-cmd --reload

    swapoff -a
    sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

    cat << EOF | tee /etc/modules-load.d/cri-o.conf
br_netfilter
EOF
    modprobe br_netfilter

    cat <<EOF | tee /etc/sysctl.d/cri-o.conf
net.ipv4.ip_forward = 1
EOF
    sysctl --system

    dnf -q install -y container-selinux

    echo -e "\nConfiguration du système : OK\n"
}

# Installation de cri-o
setup_crio() {
    readonly REPO_CRIO_VERSION="${k8s_version%.*}"

    cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/v$REPO_CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/v$REPO_CRIO_VERSION/rpm/repodata/repomd.xml.key
exclude=cri-o
EOF

    dnf -q install -y cri-o --disableexcludes=cri-o
    systemctl enable --now crio.service

    echo -e "\nInstallation de cri-o : OK\n"
}

# Installation des packages du nfs client
setup_nfs_client() {
    dnf -q install -y nfs-utils nfs4-acl-tools

    echo -e "\nInstallation du client NFS : OK\n"
}

# Installation des packages de kubernetes
setup_kubernetes() {
    readonly REPO_K8S_VERSION="${k8s_version%.*}"

    cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$REPO_K8S_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$REPO_K8S_VERSION/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    dnf -q install -y kubelet-$k8s_version kubeadm-$k8s_version kubectl-$k8s_version --disableexcludes=kubernetes
    systemctl enable --now kubelet

    echo -e "\nInstallation des packages de kubernetes : OK\n"
}

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
    local result=$?

    if [ "$result" != "0" ]; then
        echo -e "\nEchec de préparation du noeud du cluster kubernetes."
    fi
    
    exit $result
}


# Execution

# Arrêter l'exécution en cas d'erreur
trap "fail_trap" EXIT
set -e

check_if_root

# Traitement des options avec getopts
while getopts ":h-:" opt; do
    case ${opt} in
        h)
          display_help
          exit 0
          ;;
        -)
            case "${OPTARG}" in
                hostfile=*)
                  hostfile="${OPTARG#*=}"
                  ;;
                k8s-version=*)
                  k8s_version="${OPTARG#*=}"
                  ;;
                help)
                  display_help
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

verify_options
check_dependency
setup_system
setup_crio
setup_nfs_client
setup_kubernetes

echo -e "\nConfiguration de base : OK\n"