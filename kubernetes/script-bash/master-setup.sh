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
default_pod_network="172.16.0.0/16"
pod_network="$default_pod_network"
api_server_ip=""
api_server_pod_running=false

readonly HAS_KUBEADM="$(type "kubeadm" &> /dev/null && echo true || echo false)"
readonly HAS_KUBECTL="$(type "kubectl" &> /dev/null && echo true || echo false)"
readonly HAS_KUBELET="$(type "kubelet" &> /dev/null && echo true || echo false)"
readonly VALIDATION_API_SERVER_IP="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
readonly VALIDATION_POD_NETWORK="^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$"

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
    echo "  -h, --help         Afficher cette aide"
    echo "  --api-server-ip    L'adresse IP sur laquelle le serveur API écoutera (Elle doit être l'adresse IP du serveur master)"
    echo "  --pod-network      Plage du réseau du cluster (valeur par défaut = $default_pod_network)"
}

check_api_server_pod_status() {
    local status
    local hostname=$(cat /etc/hostname)
    status=$(kubectl get pod --no-headers kube-apiserver-$hostname -n kube-system -o custom-columns=CONTAINER:.status.phase)
    if [ "$status" = "Running" ]; then
        api_server_pod_running=true
    else
        sleep 5
    fi
}

# Vérification des options entrées
verify_options() {
    if [[ -z $api_server_ip ]]; then
        echo "L'option --api-server-ip est obligatoire."
        display_help
        exit 1
    fi
    
    if ! [[ $api_server_ip =~ $VALIDATION_API_SERVER_IP ]]; then
        echo "Erreur: $api_server_ip n'est pas sous le format d'adresse ipv4 (ex: 192.168.56.1)."
        exit 1
    fi

    if ! [[ $pod_network =~ $VALIDATION_POD_NETWORK ]]; then
        echo "Erreur: $pod_network n'est pas sous le format cidr (ex: $default_pod_network)."
        exit 1
    fi
}

# Vérification de la présence des packages kubeadm, kubelet et kubectl
check_dependency() {
    if [ "$HAS_KUBEADM" != "true" ] || [ "$HAS_KUBECTL" != "true" ] || [ "$HAS_KUBELET" != "true" ] ; then
        echo "Veuillez installer les packages kubeadm, kubelet et kubectl pour exécuter ce script. Veuillez utiliser le script common-setup.sh"
        exit 1
    fi
}

# Initialisation du cluster kubernetes
init_cluster() {
    firewall-cmd --permanent --add-port={6443,2379-2380,10250,10257,10259}/tcp
    firewall-cmd --reload

    readonly k8S_VERSION=$(echo "$(kubelet --version)" | grep -oP '\d+\.\d+\.\d+')
    kubeadm init --pod-network-cidr $pod_network --apiserver-advertise-address $api_server_ip --kubernetes-version $k8S_VERSION
   
    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
    chown $(id -u):$(id -g) /root/.kube/config

    while ! $api_server_pod_running; do
        check_api_server_pod_status
    done

    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

    kubeadm token create --print-join-command > /home/vagrant/shared/join-command.sh

    echo -e "\nInitialisation du cluster kubernetes : OK\n"
}

# fail_trap est exécuté si une erreur se produit.
fail_trap() {
    local result=$?
    
    if [ "$result" != "0" ]; then
        echo -e "\nEchec de configuration du noeud master du cluster kubernetes."
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
                api-server-ip=*)
                  api_server_ip="${OPTARG#*=}"
                  ;;
                pod-network=*)
                  pod_network="${OPTARG#*=}"
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
init_cluster

echo -e "\nConfiguration du noeud master : OK\n"