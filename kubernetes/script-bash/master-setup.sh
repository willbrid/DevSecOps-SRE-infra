#!/bin/bash

################################################################################
# Description :
#   Ce script Bash automatisé est conçu pour initialiser un cluster Kubernetes 
#   sur une machine vagrant Rocky linux 8.
#
# Utilisation :
#   sudo ./master-setup.sh [options]
#
# Options :
#   -h, --help         Afficher cette aide
#   --api-server-ip    L'adresse IP sur laquelle le serveur API écoutera (Elle doit être l'adresse IP du serveur master)
#   --pod-network      Plage du réseau du cluster (valeur par défaut = 172.16.0.0/16)

# Vérification de l'exécution en mode root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Initialisation des variables
defaultPodnetwork="172.16.0.0/16"
podnetwork="$defaultPodnetwork"
validationPodnetwork=""
apiServerIP=""
validationApiServerIP=""
apiServerPodRunning=false
k8sVersion=""

# Définition de la fonction d'aide
function displayHelp {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help         Afficher cette aide"
    echo "  --api-server-ip    L'adresse IP sur laquelle le serveur API écoutera (Elle doit être l'adresse IP du serveur master)"
    echo "  --pod-network      Plage du réseau du cluster (valeur par défaut = $defaultPodnetwork)"
    exit 0
}

function checkApiserverPodStatus {
    local status
    local hostname=$(cat /etc/hostname)
    status=$(kubectl get pod --no-headers kube-apiserver-$hostname -n kube-system -o custom-columns=CONTAINER:.status.phase)
    if [ "$status" = "Running" ]; then
        apiServerPodRunning=true
    else
        sleep 5
    fi
}

# Traitement des options avec getopts
while getopts ":h-:" opt; do
    case ${opt} in
        h)
          displayHelp
          ;;
        -)
            case "${OPTARG}" in
                api-server-ip=*)
                  apiServerIP="${OPTARG#*=}"
                  ;;
                pod-network=*)
                  podnetwork="${OPTARG#*=}"
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

# Vérification de la présence de l'option --api-server-ip
if [[ -z $apiServerIP ]]; then
    echo "L'option --api-server-ip est obligatoire."
    displayHelp
fi

# Vérification du format de l'adresse IP du serveur API
validationApiServerIP="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
if ! [[ $apiServerIP =~ $validationApiServerIP ]]; then
    echo "Erreur: $apiServerIP n'est pas sous le format d'adresse ipv4 (ex: 192.168.56.1)."
    exit 1
fi

# Vérification du format de la plage du réseau du cluster
validationPodnetwork="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"
if ! [[ $podnetwork =~ $validationPodnetwork ]]; then
    echo "Erreur: $podnetwork n'est pas sous le format cidr (ex: $defaultPodnetwork)."
    exit 1
fi

# Vérification de la présence des packages kubeadm, kubelet et kubectl
if ! command -v kubeadm &> /dev/null || ! command -v kubelet &> /dev/null || ! command -v kubectl &> /dev/null; then
    echo "Veuillez installer les packages kubeadm, kubelet et kubectl pour exécuter ce script. Veuillez utiliser le script initialsetup.sh"
    exit 1
fi


echo -e "\n----Autorisation des ports par défaut des composants du noeud master----\n"

firewall-cmd --permanent --add-port={6443,2379-2380,10250,10251,10252}/tcp
firewall-cmd --reload


echo -e "\n----Initialisation du cluster sur le noeud master----\n"

k8sVersion=$(echo "$(kubelet --version)" | grep -oP '\d+\.\d+\.\d+')
kubeadm init --pod-network-cidr $podnetwork --apiserver-advertise-address $apiServerIP --kubernetes-version $k8sVersion
if [ $? -ne 0 ]; then
    echo "Echec d'initialisation du cluster"
    exit 1
fi
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config


echo -e "\n----Installation du module complémentaire réseau Calico----\n"

while ! $apiServerPodRunning; do
    checkApiserverPodStatus
done

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml


echo -e "\n----Création du script d'ajout des noeuds workers au cluster----\n"

kubeadm token create --print-join-command > /home/vagrant/shared/join-command.sh


echo -e "\n----Configuration du noeud master avec succès----\n"