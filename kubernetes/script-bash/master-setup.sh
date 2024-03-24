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

# Initialisation des variables
HAS_KUBEADM="$(type "kubeadm" &> /dev/null && echo true || echo false)"
HAS_KUBECTL="$(type "kubectl" &> /dev/null && echo true || echo false)"
HAS_KUBELET="$(type "kubelet" &> /dev/null && echo true || echo false)"
HAS_CONTAINERD="$(type "/usr/local/bin/containerd" &> /dev/null && echo true || echo false)"

defaultPodnetwork="172.16.0.0/16"
podnetwork="$defaultPodnetwork"
validationPodnetwork=""
apiServerIP=""
validationApiServerIP=""
apiServerPodRunning=false
k8sVersion=""

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
    echo "  -h, --help         Afficher cette aide"
    echo "  --api-server-ip    L'adresse IP sur laquelle le serveur API écoutera (Elle doit être l'adresse IP du serveur master)"
    echo "  --pod-network      Plage du réseau du cluster (valeur par défaut = $defaultPodnetwork)"
}

checkApiserverPodStatus() {
    local status
    local hostname=$(cat /etc/hostname)
    status=$(kubectl get pod --no-headers kube-apiserver-$hostname -n kube-system -o custom-columns=CONTAINER:.status.phase)
    if [ "$status" = "Running" ]; then
        apiServerPodRunning=true
    else
        sleep 5
    fi
}

# Vérification des options entrées
verifyOptions() {
    if [[ -z $apiServerIP ]]; then
        echo "L'option --api-server-ip est obligatoire."
        displayHelp
        exit 1
    fi

    validationApiServerIP="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    if ! [[ $apiServerIP =~ $validationApiServerIP ]]; then
        echo "Erreur: $apiServerIP n'est pas sous le format d'adresse ipv4 (ex: 192.168.56.1)."
        exit 1
    fi

    validationPodnetwork="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"
    if ! [[ $podnetwork =~ $validationPodnetwork ]]; then
        echo "Erreur: $podnetwork n'est pas sous le format cidr (ex: $defaultPodnetwork)."
        exit 1
    fi
}

# Vérification de la présence des packages kubeadm, kubelet, kubectl et containerd
checkDependency() {
    if [ "${HAS_KUBEADM}" != "true" ] || [ "${HAS_KUBECTL}" != "true" ] || [ "${HAS_KUBELET}" != "true" ] || [ "${HAS_CONTAINERD}" != "true" ]; then
        echo "Veuillez installer les packages kubeadm, kubelet, kubectl et containerd pour exécuter ce script. Veuillez utiliser le script common-setup.sh"
        exit 1
    fi
}

# Initialisation du cluster kubernetes
initCluster() {
    echo -e "\nInitialisation du cluster kubernetes en cours...\n"

    firewall-cmd --permanent --add-port={6443,2379-2380,10250,10251,10252}/tcp
    firewall-cmd --reload

    k8sVersion=$(echo "$(kubelet --version)" | grep -oP '\d+\.\d+\.\d+')
    kubeadm init --pod-network-cidr $podnetwork --apiserver-advertise-address $apiServerIP --kubernetes-version $k8sVersion
   
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    chown $(id -u):$(id -g) /root/.kube/config

    while ! $apiServerPodRunning; do
        checkApiserverPodStatus
    done

    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

    kubeadm token create --print-join-command > /home/vagrant/shared/join-command.sh

    echo -e "\nInitialisation du cluster kubernetes : OK\n"
}

# failTrap est exécuté si une erreur se produit.
failTrap() {
    local result=$?
    
    if [ "$result" != "0" ]; then
        echo -e "\tEchec de configuration du noeud master du cluster kubernetes."
    fi
    
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
                api-server-ip=*)
                  apiServerIP="${OPTARG#*=}"
                  ;;
                pod-network=*)
                  podnetwork="${OPTARG#*=}"
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
checkDependency
initCluster

echo -e "\nConfiguration du noeud master : OK\n"