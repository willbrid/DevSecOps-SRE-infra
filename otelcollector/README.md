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

### Référence

- [Opentelemetry Documentation](https://opentelemetry.io/docs)