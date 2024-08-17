# Opensearch

**OpenSearch** est un moteur de recherche et d'analyse distribué qui prend en charge divers cas d'utilisation, de la mise en œuvre d'un champ de recherche sur un site Web à l'analyse des données de sécurité pour la détection des menaces. Le terme distribué signifie que nous pouvons exécuter **OpenSearch** sur plusieurs ordinateurs. La recherche et l'analyse signifient que nous pouvons rechercher et analyser nos données une fois que nous les avons ingérées dans **OpenSearch**. Quel que soit notre type de données, nous pouvons les stocker et les analyser à l'aide d'**OpenSearch**.

### Installation sur k8s depuis le noeud master

Au préalable nous créons l'espace de nom **opensearch**

```
kubectl create namespace opensearch
```

Nous clonons le référentiel github willbrid/DevSecOps-SRE-infra

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/opensearch/k8s-manifest
```

```
kubectl apply -f *.yaml
```

### Référence

- [Opensearch Documentation](https://opensearch.org/docs/latest/about/)