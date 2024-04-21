#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour installer et configurer un serveur 
#   nfs sous un système Rocky linux 8.
#
# Utilisation :
#   sudo ./nfs-server-setup.sh [options]
#
# Options :
#   -h, --help              Afficher cette aide
#   --nfs-network           Adresse CIDR à autoriser
#   --device-name           Nom du phériphérique à partitionner
#   --device-num            Numéro de la partition primaire à créer
#   --device-size           Valeur de pourcentage de stockage de la partition primaire à créer. Valeur entre 1 et 100. Par défaut : 100

# Initialisation des variables
nfs_network=""
device_name=""
device_num=""
device_size="100"

readonly VALIDATION_NFS_NETWORK="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"
readonly SHARED_NAME="nfsshared"

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
    echo "  --nfs-network           Adresse CIDR à autoriser"
    echo "  --device-name           Nom du phériphérique à partitionner"
    echo "  --device-num            Numéro de la partition primaire à créer"
    echo "  --device-size           Valeur de pourcentage de stockage de la partition primaire à créer. Valeur entre 1 et 100. Par défaut : 100"
}

# Vérification des options entrées
verify_options() {
    if [[ -z $nfs_network ]]; then
        echo "L'option --nfs-network est obligatoire."
        display_help
        exit 1
    fi

    
    if ! [[ $nfs_network =~ $VALIDATION_NFS_NETWORK ]]; then
        echo "Erreur: $nfs_network n'est pas sous le format cidr (ex: 192.168.56.0/24)."
        exit 1
    fi

    if ! lsblk | grep -i "$device_name"; then
        echo "Le périphérique $device_name n'est pas présent."
        exit 1
    else
        device_name="/dev/$device_name"
    fi

    device_num=$(expr "$device_num" + 0)
    if [ $? -ne 0 ]; then
        echo "Veuillez entrer un numéro de phériphérique compris entre 1 et 4."
        exit 1
    fi
    if (( $device_num < 1 || $device_num > 4 )); then
        echo "Le numéro $device_num de partition primaire n'est pas compris entre 1 et 4."
        exit 1
    fi

    device_size=$(expr "$device_size" + 0)
    if [ $? -ne 0 ]; then
        echo "Veuillez entrer une valeur de pourcentage du stockage de partition primaire comprise entre 1 et 100."
        exit 1
    fi
    if (( $device_size < 1 || $device_size > 100 )); then
        echo "La valeur de pourcentage $device_size du stockage de partition primaire n'est pas comprise entre 1 et 100."
        exit 1
    fi
}

# Configuration de l'espace de stockage NFS
configure_nfs_storage() {
    mkdir -p /data

    if ! ls -l $device_name$device_num &> /dev/null; then
        parted -s -a optimal -- $device_name mklabel gpt
        parted -s -a optimal -- $device_name mkpart primary ext4 0% $device_size"%"
        parted -s -- $device_name align-check optimal $device_num
        mkfs.ext4 $device_name$device_num
        echo "$device_name$device_num /data ext4 defaults 0 0" | tee -a /etc/fstab
        mount -a
    else
        if ! df -h | grep /data; then
            echo "$device_name$device_num /data ext4 defaults 0 0" | tee -a /etc/fstab
            mount -a
        fi
    fi

    echo -e "\nConfiguration du stockage NFS : OK\n"
}

# Configuration du service de stockage NFS
configure_nfs_service() {
    dnf -q install -y nfs-utils

    mkdir -p /data/$SHARED_NAME
    chown nobody:nobody /data/$SHARED_NAME
    chmod 2770 /data/$SHARED_NAME

    echo -e "/data/$SHARED_NAME\t$nfs_network(rw,sync,no_subtree_check,no_root_squash)" | tee -a /etc/exports
    exportfs -av
    systemctl enable --now rpcbind nfs-server

    firewall-cmd --permanent --add-service={nfs,nfs3,mountd,rpc-bind}
    firewall-cmd --reload

    setsebool -P nfs_export_all_rw 1

    echo -e "\nConfiguration du service de stockage NFS : OK\n"
}

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
    local result=$?
    
    if [ "$result" != "0" ]; then
        echo -e "\nEchec de configuration du serveur NFS."
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
                nfs-network=*)
                  nfs_network="${OPTARG#*=}"
                  ;;
                device-name=*)
                  device_name="${OPTARG#*=}"
                  ;;
                device-num=*)
                  device_num="${OPTARG#*=}"
                  ;;
                device-size=*)
                  device_size="${OPTARG#*=}"
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
configure_nfs_storage
configure_nfs_service

echo -e "\nConfiguration du serveur NFS : OK\n"