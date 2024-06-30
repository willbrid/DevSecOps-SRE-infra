# Minio

MinIO est un serveur de stockage objet open source, compatible avec l'API Amazon S3 (Simple Storage Service). Il est adapté aux applications nécessitant du stockage de données à grande échelle tout en offrant des fonctionnalités avancées de haute disponibilité, de sécurité et d'intégration.

### Installation sur k8s depuis le noeud master

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/minio/k8s-manifest
```

```
kubectl apply -f *.yaml
```

Nous accédons à l'interface via le lien : **https://minio-storage.willbrid.com** .

### Référence

- [Minio Documentation](https://min.io/docs)