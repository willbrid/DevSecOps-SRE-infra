# Graylog

Graylog est une puissante solution de gestion des informations et des événements de sécurité (SIEM) offrant une plate-forme d'analyse de journaux robuste qui simplifie la collecte, la recherche, l'analyse et l'alerte de tous les types de données générées par machine. Elle est spécifiquement conçue pour capturer des données provenant de diverses sources, nous permettant de centraliser, de sécuriser et de surveiller efficacement nos données de journal. Graylog peut exécuter une large gamme de fonctions de cybersécurité, telles que :
- agrégation de données
- analyse des données de sécurité (rapports et tableaux de bord)
- corrélation et surveillance des événements de sécurité
- analyse médico-légale
- détection et réponse aux incidents
- réponse aux événements en temps réel ou console d'alerte
- intelligence des menaces
- analyse du comportement des utilisateurs et des entités (UEBA)
- gestion de la conformité informatique

**Graylog Open** est la version gratuite et open source du logiciel Graylog, qui offre des fonctionnalités de gestion centralisée des journaux pour la collecte, l'enrichissement, le stockage et l'analyse des données provenant de diverses sources.

**Préréquis**: Au préalable il faudrait d'abord installer **mongoDB** et **opensearch** via ce même référentiel.

### Installation sur k8s depuis le noeud master

Au préalable nous créons l'espace de nom **graylog**

```
kubectl create namespace graylog
```

Nous clonons le référentiel github willbrid/DevSecOps-SRE-infra

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/graylog/k8s-manifest
```

```
kubectl apply -f *.yaml
```

### Référence

- [Graylog Documentation](https://go2docs.graylog.org/current/what_is_graylog/what_is_graylog.htm)