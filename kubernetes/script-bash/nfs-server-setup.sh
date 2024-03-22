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

# Vérification de l'exécution en mode root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Initialisation des variables
nfsnetwork=""
sharedname="nfsshared"
validationNFSnetwork=""
deviceName=""
deviceNum=""
deviceSize="100"

# Définition de la fonction d'aide
function displayHelp {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  --nfs-network           Adresse CIDR à autoriser"
    echo "  --device-name           Nom du phériphérique à partitionner"
    echo "  --device-num            Numéro de la partition primaire à créer"
    echo "  --device-size           Valeur de pourcentage de stockage de la partition primaire à créer. Valeur entre 1 et 100. Par défaut : 100"
    exit 0
}

# Traitement des options avec getopts
while getopts ":h-:" opt; do
    case ${opt} in
        h)
          displayHelp
          ;;
        -)
            case "${OPTARG}" in
                nfs-network=*)
                  nfsnetwork="${OPTARG#*=}"
                  ;;
                device-name=*)
                  deviceName="${OPTARG#*=}"
                  ;;
                device-num=*)
                  deviceNum="${OPTARG#*=}"
                  ;;
                device-size=*)
                  deviceSize="${OPTARG#*=}"
                  ;;
                help)
                  displayHelp
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

# Vérification de la présence de l'option --nfs-network
if [[ -z $nfsnetwork ]]; then
    echo "L'option --nfs-network est obligatoire."
    displayHelp
fi

# Vérification du format de la valeur de l'option --nfs-network
validationNFSnetwork="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"
if ! [[ $nfsnetwork =~ $validationNFSnetwork ]]; then
    echo "Erreur: $nfsnetwork n'est pas sous le format cidr (ex: 192.168.56.0/24)."
    exit 1
fi

if ! lsblk | grep -i "$deviceName"; then
    echo "Le périphérique $deviceName n'est pas présent."
    exit 1
else
    deviceName="/dev/$deviceName"
fi

deviceNum=$(expr "$deviceNum" + 0)
if [ $? -ne 0 ]; then
    echo "Veuillez entrer un numéro de phériphérique compris entre 1 et 4."
    exit 1
fi
if (( $deviceNum < 1 || $deviceNum > 4 )); then
    echo "Le numéro $deviceNum de partition primaire n'est pas compris entre 1 et 4."
    exit 1
fi

deviceSize=$(expr "$deviceSize" + 0)
if [ $? -ne 0 ]; then
    echo "Veuillez entrer une valeur de pourcentage du stockage de partition primaire comprise entre 1 et 100."
    exit 1
fi
if (( $deviceSize < 1 || $deviceSize > 100 )); then
    echo "La valeur de pourcentage $deviceSize du stockage de partition primaire n'est pas comprise entre 1 et 100."
    exit 1
fi

echo -e "\n----Création et montage d'une partition de stockage NFS----\n"

mkdir -p /data
if ! ls -l $deviceName$deviceNum &> /dev/null; then
    parted -s -a optimal -- $deviceName mklabel gpt
    parted -s -a optimal -- $deviceName mkpart primary ext4 0% $deviceSize"%"
    parted -s -- $deviceName align-check optimal $deviceNum
    mkfs.ext4 $deviceName$deviceNum
    echo "$deviceName$deviceNum /data ext4 defaults 0 0" | tee -a /etc/fstab
    mount -a
else
    if ! df -h | grep /data; then
        echo "$deviceName$deviceNum /data ext4 defaults 0 0" | tee -a /etc/fstab
        mount -a
    fi
fi


echo -e "\n----Installation du package nfs-utils et configuration du service NFS----\n"

dnf install -y nfs-utils
if [ $? -ne 0 ]; then
    echo "Echec d'installation du package nfs-utils"
    exit 1
fi
mkdir -p /data/$sharedname
chown nobody:nobody /data/$sharedname
chmod 2770 /data/$sharedname
echo -e "/data/$sharedname\t$nfsnetwork(rw,sync,no_subtree_check,no_root_squash)" | tee -a /etc/exports
exportfs -av
systemctl enable --now rpcbind nfs-server


echo -e "\n----Autorisation des services pour NFS----\n"

firewall-cmd --permanent --add-service={nfs,nfs3,mountd,rpc-bind}
firewall-cmd --reload


echo -e "\n----Configuration de selinux pour le service NFS----\n"

setsebool -P nfs_export_all_rw 1


echo -e "\n----Configuration du serveur NFS avec succès----\n"