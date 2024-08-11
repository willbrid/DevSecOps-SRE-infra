# Keycloak

**Keycloak** est un outil open source de gestion des identités et des accès (**IAM - Identity and Access Management**). Il fournit des fonctionnalités robustes pour l'authentification, l'autorisation et la gestion des utilisateurs dans les applications modernes.

**Caractéristiques principales de Keycloak** :

- **Authentification et Single Sign-On (SSO)** : **Keycloak** permet de centraliser l'authentification des utilisateurs pour différentes applications. Avec SSO, les utilisateurs peuvent se connecter une seule fois et accéder à toutes les applications autorisées sans avoir à se reconnecter.

- **Gestion des utilisateurs** : **Keycloak** offre une interface conviviale pour la gestion des utilisateurs, y compris la création de comptes, la gestion des rôles, l'attribution de permissions, et plus encore.

- **Support pour divers protocoles** : **Keycloak** supporte plusieurs protocoles d'authentification standardisés comme OAuth 2.0, OpenID Connect, et SAML 2.0, ce qui le rend compatible avec une large gamme d'applications.

- **Federation et intégration avec des annuaires externes** : Il permet l'intégration avec des annuaires existants comme LDAP, Active Directory, ou d'autres bases de données pour synchroniser et gérer les identités.

- **Personnalisation** : **Keycloak** offre des options de personnalisation pour les pages de connexion, les flux d'authentification, et les mécanismes de récupération de mot de passe, permettant ainsi de l'adapter aux besoins spécifiques des entreprises.

- **Gestion de l'autorisation** : **Keycloak** fournit des outils pour définir des politiques d'autorisation complexes, basées sur les rôles des utilisateurs, leurs attributs, ou d'autres critères spécifiques.

**Utilisation de Keycloak** :

**Keycloak** est couramment utilisé dans des environnements où plusieurs applications nécessitent une gestion centralisée des identités et où la sécurité est une priorité. Il est particulièrement utile pour les organisations cherchant à simplifier l'authentification des utilisateurs tout en assurant une sécurité robuste et une conformité aux normes.

### Installation sur k8s depuis le noeud master

Au préalable nous créons l'espace de nom **keycloak**

```
kubectl create namespace keycloak
```

Nous clonons le référentiel github **willbrid/DevSecOps-SRE-infra**

```
git clone https://github.com/willbrid/DevSecOps-SRE-infra.git
```

```
cd DevSecOps-SRE-infra/keycloak/k8s-manifest
```

```
kubectl apply -f *.yaml
```

### Référence

- [Keycloak Documentation](https://www.keycloak.org/guides)