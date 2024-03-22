# Kubernetes

Kubernetes est une plateforme open source de gestion d'orchestration de conteneurs largement utilisée pour automatiser le déploiement, la mise à l'échelle et la gestion d'applications conteneurisées. Conçu à l'origine par Google et maintenant maintenu par la Cloud Native Computing Foundation (CNCF), Kubernetes fournit un environnement de déploiement robuste et flexible pour les applications modernes basées sur des conteneurs.

### Bac à sable

Nous mettons en place notre sandbox d'installation de kubernetes via l'utilitaire **vagrant** depuis une machine hôte **ubuntu 20.04**, qui nous permettra d'installer :
- 3 machines virtuelles virtualbox **Rocky linux 8.9** pour notre cluster kubernetes : 1 noeud master et 2 noeuds worker
- 1 machine virtuelle virtualbox **Rocky linux 8.9** pour les services DNS et stockage NFS

<p align="center">
<img src="./images/physical-architecture.png" alt="physical-architecture.png" width="620" height="520" />
</p>

```
mkdir ~/kubernetes && cd ~/kubernetes
wget https://download.virtualbox.org/virtualbox/7.0.12/VBoxGuestAdditions_7.0.12.iso
```

```
vi Vagrantfile
```

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vbguest.auto_update = false
  config.vbguest.no_remote = true
  config.vbguest.iso_path = "./VBoxGuestAdditions_7.0.12.iso"

  # General Vagrant VM configuration.
  config.vm.box = "willbrid/rockylinux8"
  config.vm.box_version = "0.0.2"
  config.ssh.insert_key = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provider :virtualbox do |v|
    v.memory = 4096
    v.cpus = 2
    v.linked_clone = true
  end
  
  config.trigger.before :up do |trigger|
    trigger.info = "Creating the shared directory at the root directory of Vagrantfile"
    trigger.run = {inline: "bash -c 'mkdir -p $(pwd)/shared'"}
  end
  config.vm.synced_folder "shared/", "/home/vagrant/shared"

  config.vm.provision "shell", inline: <<-SHELL, privileged: true
    if ! command -v git &> /dev/null; then
        echo "Git is not installed, installation in progress..."
        dnf install -y git
    fi
  SHELL

  # Master
  config.vm.define "control-node" do |srv|
    srv.vm.hostname = "control-node"
    srv.vm.network :private_network, ip: "192.168.56.200"
    srv.vm.provider :virtualbox do |v|
        v.memory = 2048
    end
  end

  # Worker1
  config.vm.define "worker-node1" do |srv|
    srv.vm.hostname = "worker-node1"
    srv.vm.network :private_network, ip: "192.168.56.201"
  end

  # Worker2
  config.vm.define "worker-node2" do |srv|
    srv.vm.hostname = "worker-node2"
    srv.vm.network :private_network, ip: "192.168.56.202"
  end

  # External-control
  config.vm.define "external-control" do |srv|
    srv.vm.hostname = "external-control"
    srv.vm.network :private_network, ip: "192.168.56.203"
    srv.vm.disk :disk, name: "storage", size: "100GB"
  end
end
```

### Installation de k8s version 1.27

- Pour tous les 3 noeuds


```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/kubernetes/script-bash
```

```
chmod +x common-setup.sh
```

--- Noeud master

```
sudo ./common-setup.sh --hostname=control --hostfile=hosts --k8s-version=1.27.0
```

--- Noeud worker1

```
sudo ./common-setup.sh --hostname=worker1 --hostfile=hosts --k8s-version=1.27.0
```

--- Noeud worker2

```
sudo ./common-setup.sh --hostname=worker2 --hostfile=hosts --k8s-version=1.27.0
```

- Sur le noeud master

```
chmod +x master-setup.sh
```

```
sudo ./master-setup.sh --api-server-ip=192.168.56.200
```

- Sur tous les noeuds workers

```
chmod +x worker-setup.sh
```

```
sudo ./worker-setup.sh
```

### Installation du service NFS sur le serveur external-control

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/kubernetes/script-bash
```

```
sudo ./nfs-server-setup.sh --nfs-network=192.168.56.0/24 --device-name=sdb --device-num=1 --device-size=50
```

### Installation du provisionneur de volume persistant dans notre cluster depuis notre noeud master

```
sudo su
```

```
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
```

```
helm install nfs-subdir-external-provisioner \
nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
--set nfs.server=192.168.56.203 \
--set nfs.path=/data/nfsshared \
--set storageClass.onDelete=true
```

### Référence

- [Kubernetes Documentation](https://kubernetes.io/docs/home/)