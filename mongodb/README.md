# MongoDB

**MongoDB** est un système de gestion de base de données (SGBD) NoSQL open source, orienté document et conçu pour stocker, organiser et récupérer des données de manière efficace et flexible.

### Installation sur k8s depuis le noeud master

Au préalable nous créons l'espace de nom **mongodb**

```
kubectl create sa mongodb
```

Nous clonons le référentiel github willbrid/DevSecOps-SRE-infra

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

- Installation en mode non HA

```
cd DevSecOps-SRE-infra/mongodb/k8s-manifest/mode-non-ha
```

```
kubectl apply -f *.yaml
```

- Installation en mode HA

--- Création du secret **mongodb-keyfile** pour le fichier de clé dans l'espace de nom **mongodb**

La configuration de l'authentification pour notre cluster MongoDB à l'aide du fichier de clé est essentielle pour sécuriser la communication entre les membres du cluster, empêcher tout accès non autorisé et garantir que seuls les nœuds approuvés peuvent rejoindre le cluster.

```
openssl rand -base64 756 > $HOME/mongodb-keyfile
```

```
kubectl create secret generic mongodb-keyfile --from-file=mongodb-keyfile=$HOME/mongodb-keyfile -n mongodb
```

--- Installation des fichiers manifests

```
cd DevSecOps-SRE-infra/mongodb/k8s-manifest/mode-ha
```

```
kubectl apply -f *.yaml
```

### Référence

- [MongoDB Documentation](https://www.mongodb.com/docs/manual/)