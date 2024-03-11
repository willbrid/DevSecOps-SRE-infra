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
#   -h, --help         Afficher cette aide
#   --hostname         Nom d'hôte à configurer
#   --hostfile         Fichier d'hôtes
#   --k8s-version      Version de Kubernetes

# Vérification de l'exécution en mode root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Initialisation des variables
hostname=""
hostfile=""
k8sversion=""
repok8sversion=""
k8spathsetting=""

# Définition de la fonction d'aide
function help {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help         Afficher cette aide"
    echo "  --hostname         Nom d'hôte à configurer"
    echo "  --hostfile         Fichier d'hôtes"
    echo "  --k8s-version      Version de Kubernetes"
    exit 1
}

# Traitement des options avec getopts
while getopts ":h:-:" opt; do
    case ${opt} in
        h)
          help
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
                  k8sversion="${OPTARG#*=}"
                  ;;
                help)
                    help
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

# Vérification que toutes les options obligatoires sont fournies
if [[ -z $hostname ]] || [[ -z $hostfile ]] || [[ -z $k8sversion ]]; then
    echo "Les options -h (--hostname), -f (--hostfile) et -k (--k8sversion) sont obligatoires."
    help
fi

# Vérification de l'existence du fichier de configuration
if [ ! -f "$hostfile" ]; then
    echo "Le fichier de configuration $hostfile n'existe pas."
    exit 1
fi

# Vérification du format de la version de k8s
validationk8sversion="^[0-9]+\.[0-9]+\.[0-9]+$"
if ! [[ $k8sversion =~ $validationk8sversion ]]; then
    echo "Erreur: $k8sversion n'est pas sous le format x.y.z où x, y et z sont des nombres."
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


echo -e "\n----Installation et configuration de containerd et runc----\n"

k8spathsetting="/etc/profile.d/usr_local_bin_path_setting.sh"
if [[ ":$PATH:" != *":/usr/local/bin:"* ]] && [[ ":$PATH:" != *":/usr/local/sbin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/bin:/usr/local/sbin' > $k8spathsetting
elif [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/bin' > $k8spathsetting
elif [[ ":$PATH:" != *":/usr/local/sbin:"* ]]; then
    echo 'export PATH=$PATH:/usr/local/sbin' > $k8spathsetting
fi
if [ -f "$k8spathsetting" ]; then
    source $k8spathsetting
fi

wget -P /tmp https://github.com/containerd/containerd/releases/download/v1.7.6/containerd-1.7.6-linux-amd64.tar.gz
tar Czxvf /usr/local /tmp/containerd-1.7.6-linux-amd64.tar.gz
wget -P /tmp https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mv /tmp/containerd.service /usr/lib/systemd/system/
chown root:root /usr/lib/systemd/system/containerd.service
restorecon /usr/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

wget -P /tmp https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64
install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
systemctl restart containerd


echo -e "\n----Installation de kubeadm, kubelet et kubectl----\n"

repok8sversion="${k8sversion%.*}"
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$repok8sversion/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$repok8sversion/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf install -y kubelet-$k8sversion kubeadm-$k8sversion kubectl-$k8sversion --disableexcludes=kubernetes
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