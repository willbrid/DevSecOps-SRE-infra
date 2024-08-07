# Grafana

**Grafana** est un outil qui permet d'interroger, de visualiser, de générer des alertes et de comprendre nos indicateurs, quel que soit l'endroit où ils sont stockés. Il permet de créer, explorer et partager des tableaux de bord avec notre équipe et favorise une culture axée sur les données. <br>
Un tableau de bord **Grafana** se compose de panneaux affichant des données dans de magnifiques graphiques, diagrammes et autres visualisations. Ces panneaux sont créés à l'aide de composants qui transforment les données brutes d'une source de données en visualisations. Le processus consiste à transmettre les données via trois **portes** : un **plug-in**, une **requête** et une **transformation facultative**.

### Installation sous k8s depuis le noeud master

Au préalable nous créons l'espace de nom **grafana**

```
kubectl create namespace grafana
```

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
cd $HOME && git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

- Installation avec Helm

```
cd DevSecOps-SRE-infra/grafana/helm
```

```
helm install grafana . --namespace grafana 
```

- Installation avec les fichiers manifest

```
cd DevSecOps-SRE-infra/grafana/k8s-manifest
```

```
kubectl apply -f *.yaml
```

[Grafana Documentation](https://grafana.com/docs/)