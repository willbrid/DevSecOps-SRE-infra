# Minio

MinIO est un serveur de stockage objet open source, compatible avec l'API Amazon S3 (Simple Storage Service). Il est adapté aux applications nécessitant du stockage de données à grande échelle tout en offrant des fonctionnalités avancées de haute disponibilité, de sécurité et d'intégration.

### Installation sur k8s depuis le noeud master

Au préalable nous créons l'espace de nom **minio**

```
kubectl create namespace minio
```

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

- Installation en mode non HA

```
cd DevSecOps-SRE-infra/minio/k8s-manifest/mode-non-ha
```

```
kubectl apply -f *.yaml
```

- Installation en mode HA

```
cd DevSecOps-SRE-infra/minio/k8s-manifest/mode-ha
```

```
kubectl apply -f *.yaml
```

L'installation va créer un lien d'accès **https://minio-storage.willbrid.com** via lequel nous accédons à l'interface web.

### Référence

- [Minio Documentation](https://min.io/docs)