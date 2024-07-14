# Redis

**Redis** est un système de stockage de données open source, distribué et hautement performant. Il est souvent qualifié de "store-clé" (key-value store) car il stocke les données sous forme de paires clé-valeur. Contrairement à d'autres systèmes de stockage de données similaires, Redis prend en charge divers types de données, notamment les chaînes, les listes, les ensembles, les ensembles ordonnés, les hachages, les bitmaps et les hyperloglogs.

### Installation sous k8s depuis le noeud master

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
cd $HOME && git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

- Installation en mode haute disponibilité

```
cd DevSecOps-SRE-infra/redis/k8s-manifest/mode-ha
```

```
kubectl apply -f *.yaml
```

- Installation en mode non haute disponibilité

```
cd DevSecOps-SRE-infra/redis/k8s-manifest/mode-non-ha
```

```
kubectl apply -f *.yaml
```

[Redis Documentation](https://redis.io/docs/about/)