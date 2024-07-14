# Static-file-server

L'outil **static-file-server** est un serveur de fichiers statiques, souvent utilisé dans des environnements conteneurisés pour servir des fichiers statiques tels que des pages HTML, des images, des scripts CSS et JavaScript, des fichiers zippés etc.

### Installation sous k8s depuis le noeud master

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
cd $HOME && git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/static-file-server/k8s-manifest
```

```
kubectl apply -f *.yaml
```