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
k8s_version=""
usr_local_bin_path_setting=""
containerd_version="1.7.13"

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
    echo "  --hostname              Nom d'hôte à configurer"
    echo "  --hostfile              Fichier d'hôtes"
    echo "  --k8s-version           Version de Kubernetes"
    echo "  --containerd-version    Version de containerd (Par défaut: 1.7.13)"
}

check_dependency() {
    if [ "$HAS_CURL" != "true" ] && [ "$HAS_WGET" != "true" ] ; then
        echo "Erreur: veuillez installer curl ou wget."
        exit 1
    fi
}

# Vérification des options entrées
verify_options() {
    if [[ -z $hostname ]] || [[ -z $hostfile ]] || [[ -z $k8s_version ]]; then
        echo "Les options --hostname, --hostfile et --k8s-version sont obligatoires."
        display_help
        exit 1
    fi

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
    # Configuration du hostname du serveur
    hostnamectl set-hostname $hostname

    while read -r ip host; do
        echo -e "$ip\t$host" >> /etc/hosts
    done < "$hostfile"

    setenforce 0
    sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

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
setup_containerd() {
    mkdir -p /usr/local/bin

    usr_local_bin_path_setting="/etc/profile.d/usr_local_bin_path_setting.sh"
    if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
        echo 'export PATH=$PATH:/usr/local/bin' > $usr_local_bin_path_setting
    fi
    if [ -f "$usr_local_bin_path_setting" ]; then
        source $usr_local_bin_path_setting
    fi

    readonly CONTAINERD_DIST="containerd-$containerd_version-linux-amd64.tar.gz"
    readonly CONTAINERD_TMP_ROOT="$(mktemp -dt containerd-installer-XXXXXXX)"
    readonly CONTAINERD_DOWNLOAD_URL="https://github.com/containerd/containerd/releases/download/v$containerd_version/$CONTAINERD_DIST"
    readonly CONTAINERD_SERVICE_DIST="containerd.service"
    readonly CONTAINERD_SERVICE_DOWNLOAD_URL="https://raw.githubusercontent.com/containerd/containerd/main/$CONTAINERD_SERVICE_DIST"

    # Télécharger containerd
    if [ "${HAS_CURL}" == "true" ]; then
        curl -SsL "$CONTAINERD_DOWNLOAD_URL" -o "$CONTAINERD_TMP_ROOT/$CONTAINERD_DIST"
    elif [ "${HAS_WGET}" == "true" ]; then
        wget -q -O "$CONTAINERD_TMP_ROOT/$CONTAINERD_DIST" "$CONTAINERD_DOWNLOAD_URL"
    fi

    tar Czxvf $CONTAINERD_TMP_ROOT $CONTAINERD_TMP_ROOT/$CONTAINERD_DIST
    mv $CONTAINERD_TMP_ROOT/bin/* /usr/local/bin/

    # Télécharger le fichier service containerd
    if [ "${HAS_CURL}" == "true" ]; then
        curl -SsL "$CONTAINERD_SERVICE_DOWNLOAD_URL" -o "$CONTAINERD_TMP_ROOT/$CONTAINERD_SERVICE_DIST"
    elif [ "${HAS_WGET}" == "true" ]; then
        wget -q -O "$CONTAINERD_TMP_ROOT/$CONTAINERD_SERVICE_DIST" "$CONTAINERD_SERVICE_DOWNLOAD_URL"
    fi

    mv "$CONTAINERD_TMP_ROOT/$CONTAINERD_SERVICE_DIST" /usr/lib/systemd/system/
    chown root:root /usr/lib/systemd/system/$CONTAINERD_SERVICE_DIST
    restorecon /usr/lib/systemd/system/$CONTAINERD_SERVICE_DIST
    systemctl daemon-reload
    systemctl enable --now containerd

    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
    systemctl restart containerd

    echo -e "\nInstallation et configuration de containerd : OK\n"
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

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
    local result=$?

    if [ "$result" != "0" ]; then
        echo -e "\nEchec de préparation du noeud du cluster kubernetes."
    fi
    
    cleanup
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
                hostname=*)
                  hostname="${OPTARG#*=}"
                  ;;
                hostfile=*)
                  hostfile="${OPTARG#*=}"
                  ;;
                k8s-version=*)
                  k8s_version="${OPTARG#*=}"
                  ;;
                containerd-version=*)
                  containerd_version="${OPTARG#*=}"
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

check_dependency
verify_options
setup_system
setup_containerd
setup_nfs_client
setup_kubernetes
cleanup

echo -e "\nConfiguration de base : OK\n"