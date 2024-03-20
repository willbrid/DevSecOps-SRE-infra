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
#   sudo ./initialsetup.sh [options]
#
# Options :
#   -h, --help              Afficher cette aide
#   --hostname              Nom d'hôte à configurer
#   --hostfile              Fichier d'hôtes
#   --k8s-version           Version de Kubernetes
#   --containerd-version    Version de containerd (Par défaut: 1.7.14)"

# Vérification de l'exécution en mode root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Initialisation des variables
hostname=""
hostfile=""
k8sVersion=""
repok8sVersion=""
k8sPathSetting=""
containerdVersion="1.7.14"

# Définition de la fonction d'aide
function displayHelp {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help              Afficher cette aide"
    echo "  --hostname              Nom d'hôte à configurer"
    echo "  --hostfile              Fichier d'hôtes"
    echo "  --k8s-version           Version de Kubernetes"
    echo "  --containerd-version    Version de containerd (Par défaut: 1.7.14)"
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

# Vérification de la présence de toutes les options obligatoires
if [[ -z $hostname ]] || [[ -z $hostfile ]] || [[ -z $k8sVersion ]]; then
    echo "Les options --hostname, --hostfile et --k8s-version sont obligatoires."
    displayHelp
fi

# Vérification de l'existence du fichier de configuration
if [ ! -f "$hostfile" ]; then
    echo "Le fichier de configuration $hostfile n'existe pas."
    exit 1
fi

# Vérification du format de la version de k8s
validationk8sVersion="^[0-9]+\.[0-9]+\.[0-9]+$"
if ! [[ $k8sVersion =~ $validationk8sVersion ]]; then
    echo "Erreur: $k8sVersion n'est pas sous le format x.y.z où x, y et z sont des nombres."
    exit 1
fi


echo -e "\n----Configuration du hostname et du fichier /etc/hosts----\n"

# Configuration du hostname du serveur
hostnamectl set-hostname $hostname

while read -r ip host; do
    echo -e "$ip\t$host" >> /etc/hosts
done < "$hostfile"


echo -e "\n----Configuration de selinux en mode permissive----\n"

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux


echo -e "\n----Ajout d'une règle masquerade NAT----\n"

firewall-cmd --add-masquerade --permanent
firewall-cmd --reload


echo -e "\n----Désactivation du swap----\n"

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


echo -e "\n----Configuration des modules kernel : overlay et br_netfilter pour containerd----\n"
cat << EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter


echo -e "\n----Activation du routage des paquets----\n"

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system


echo -e "\n----Installation et configuration de containerd----\n"

k8sPathSetting="/etc/profile.d/usr_local_bin_path_setting.sh"
if [[ ":$PATH:" != *":/usr/local/bin:"* ]] && [[ ":$PATH:" != *":/usr/local/sbin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/bin:/usr/local/sbin' > $k8sPathSetting
elif [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/bin' > $k8sPathSetting
elif [[ ":$PATH:" != *":/usr/local/sbin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/sbin' > $k8sPathSetting
fi
if [ -f "$k8sPathSetting" ]; then
    source $k8sPathSetting
fi

wget -P /tmp https://github.com/containerd/containerd/releases/download/v$containerdVersion/containerd-$containerdVersion-linux-amd64.tar.gz
tar Czxvf /usr/local /tmp/containerd-$containerdVersion-linux-amd64.tar.gz
wget -P /tmp https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mv /tmp/containerd.service /usr/lib/systemd/system/
chown root:root /usr/lib/systemd/system/containerd.service
restorecon /usr/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd


echo -e "\n----Installation de kubeadm, kubelet et kubectl----\n"

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

dnf install -y kubelet-$k8sVersion kubeadm-$k8sVersion kubectl-$k8sVersion --disableexcludes=kubernetes
if [ $? -ne 0 ]; then
    echo "Echec d'installation des packages kubeadm, kubelet et kubectl"
    exit 1
fi
systemctl enable --now kubelet


echo -e "\n----Configuration de cri-tools pour sa connexion à containerd----\n"

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: true
EOF


echo -e "\n----Initialisation complète----\n"