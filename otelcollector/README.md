# OpenTelemetry Collector

### Qu'est-ce qu'OpenTelemetry ?

**OpenTelemetry** est :

- Un framework et une boîte à outils d'observabilité conçus pour créer et gérer des données de télémétrie telles que des **traces**, des **métriques** et des **logs**.

- Indépendant des fournisseurs et des outils, ce qui signifie qu'il peut être utilisé avec une grande variété de backends d'observabilité, y compris des outils open source comme **Jaeger** et **Prometheus**, ainsi que des **outils commerciaux**.

- Il ne s'agit pas d'un backend d'observabilité comme **Jaeger**, **Prometheus** ou d'autres **outils commerciaux**.

- Il est axé sur la **génération**, la **collecte**, la **gestion** et l'**exportation** de la télémétrie. L'un des principaux objectifs d'**OpenTelemetry** est que nous puissions facilement instrumenter nos applications ou systèmes, quels que soient leur **langage**, leur **infrastructure** ou leur **environnement d'exécution**. Le stockage et la visualisation de la télémétrie sont intentionnellement laissés à d'autres outils.

### Qu'est-ce que l'observabilité ?

L'**observabilité** est la capacité à comprendre l'état interne d'un système en examinant ses sorties. Dans le contexte des logiciels, cela signifie être capable de comprendre l'état interne d'un système en examinant ses données de télémétrie, qui incluent des **traces**, des **métriques** et des **logs**.

Pour rendre un système **observable**, il doit être **instrumenté**. Autrement dit, le code doit émettre des **traces**, des **métriques** ou des **logs**. Les données instrumentées doivent ensuite être envoyées à un backend d'observabilité.

### OpenTelemetry Collector

**OpenTelemetry Collector** offre une implémentation indépendante du fournisseur de la manière de recevoir, de traiter et d'exporter des données de télémétrie. Il élimine le besoin d'exécuter, d'exploiter et de maintenir plusieurs agents/collecteurs. Cela fonctionne avec une évolutivité améliorée et prend en charge les formats de données d'observabilité open source (par exemple, **Jaeger**, **Prometheus**, **Fluent Bit**, etc.) envoyés à un ou plusieurs backends open source ou commerciaux. L'**agent Collector local** est l'emplacement par défaut vers lequel les bibliothèques d'instrumentation exportent leurs données de télémétrie.

### Installation d'OpenTelemetry Collector sur k8s pour une intégration avec Prometheus

L'intégration d'**OpenTelemetry Collector** avec **Prometheus** permet de centraliser la collecte, la transformation et l'exportation des métriques générées par nos applications. **OpenTelemetry Collector** agit comme un intermédiaire entre les applications instrumentées et **Prometheus**, facilitant ainsi la gestion des métriques dans des environnements distribués. Cette configuration permet à nos applications de pousser des métriques directement vers **OpenTelemetry Collector**, qui se charge ensuite de les mettre à disposition de **Prometheus** pour la surveillance et l'analyse. <br>
L'intégration d'**OpenTelemetry Collector** avec **Prometheus** offre plusieurs avantages, tels que l'unification des points de collecte, la transformation des métriques en différents formats, et la simplification de l'architecture globale de surveillance.

Pour son installation depuis le noeud master, nous créons au préalable l'espace de nom **otelcollector**

```
kubectl create namespace otelcollector
```

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
cd $HOME && git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

- Installation avec Helm

```
cd DevSecOps-SRE-infra/otelcollector/helm
```

```
helm install otelcollector . --namespace otelcollector 
```

- Installation avec les fichiers manifest

```
cd DevSecOps-SRE-infra/otelcollector/k8s-manifest
```

```
kubectl apply -f *.yaml
```

### Référence

- [Opentelemetry Documentation](https://opentelemetry.io/docs)