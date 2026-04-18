# API d'Analyse Prédictive - Architecture DevSecOps

## Vue d'ensemble

Ce dépôt contient le code source, les définitions d'infrastructure et les scripts d'automatisation pour une API d'Analyse Prédictive Machine Learning hautement sécurisée et évolutive. Le projet a été conçu avec une approche DevSecOps stricte, garantissant que la sécurité est intégrée à chaque étape du cycle de vie du développement logiciel (SDLC).

Le backend est développé en Node.js, s'appuie sur une implémentation SQL pure pour les interactions avec la base de données, et est déployé sur un cluster Kubernetes managé.

## Architecture et Stack Technologique

Le projet utilise la stack technologique suivante pour atteindre une architecture résiliente et sécurisée :

*   **Backend Applicatif :** Node.js, Express, Jest, Supertest
*   **Base de données :** PostgreSQL (Cloud RDS)
*   **Conteneurisation :** Docker (Builds multi-étapes)
*   **Automatisation CI/CD :** Jenkins (Pipeline Déclaratif)
*   **Inspection Continue et Sécurité :** SonarQube (SAST), Trivy (Scan de conteneurs), OWASP ZAP (DAST)
*   **Orchestration :** Kubernetes (Deployment, Service, HPA, RBAC, NetworkPolicies)
*   **Infrastructure as Code (IaC) :** Terraform (Provider Huawei Cloud)
*   **Gestion de Configuration :** Ansible

## Structure du Repository

Le monorepo est organisé pour séparer clairement le code applicatif de l'infrastructure et des règles de déploiement :

```text
.
├── apps/
│   └── ml-api/                  # Code source de l'API Node.js, tests et Dockerfile
├── k8s/
│   └── base/                    # Manifestes Kubernetes (Deployment, HPA, Service, RBAC)
├── terraform/                   # IaC Terraform pour Huawei Cloud (CCE, RDS, Réseau)
├── ansible/                     # Playbooks et Rôles Ansible (Durcissement sécu, config K8s)
├── Jenkinsfile                  # Définition du pipeline DevSecOps CI/CD déclaratif
└── sonar-project.properties     # Configuration SonarQube pour le SAST
```

## Spécifications Détaillées des Composants

### 1. Infrastructure as Code (Terraform)
L'infrastructure est provisionnée via Terraform sur Huawei Cloud.
*   **Gestion de l'État (State) :** Les fichiers d'état sont stockés de manière sécurisée à distance sur Object Storage (OBS) pour éviter l'exposition locale des secrets et permettre la collaboration en équipe.
*   **Réseau :** Séparation des VPC avec des Groupes de Sécurité stricts. L'instance PostgreSQL RDS n'a pas d'accès public et accepte le trafic entrant exclusivement des nœuds du cluster Kubernetes (CCE).
*   **Compute :** Cluster Kubernetes Managé (CCE v3) avec auto-scaling des pools de nœuds fonctionnant sous un EulerOS durci.

### 2. Gestion de Configuration (Ansible)
Ansible est utilisé pour appliquer les configurations de manière idempotente au niveau des Nœuds et du Cluster.
*   **Rôle security-hardening :** Applique les standards du benchmark CIS sur les nœuds du cluster (Désactivation de la connexion SSH en root, obligation de l'authentification par clé publique, durcissement des paramètres sysctl du noyau contre les attaques réseau, et installation de auditd).
*   **Rôle k8s-config :** Automatise la création des namespaces staging/production et établit un environnement réseau Zero Trust en déployant une NetworkPolicy "deny-all" par défaut.

### 3. Sécurité Applicative & Conteneurisation (Docker)
L'API Node.js est empaquetée via un Dockerfile hautement optimisé.
*   **Build Multi-stade :** Utilise `node:20-alpine` comme base, compile le code et supprime les dépendances de développement (`npm prune --production`) avant de transférer l'artefact final vers l'image de production.
*   **Moindre Privilège :** Le conteneur s'exécute sous un utilisateur non-root (`node` avec l'UID 1000).
*   **Builds Déterministes :** Utilise `npm ci --ignore-scripts` pour prévenir les attaques de la supply chain via des scripts de post-installation non autorisés.

### 4. Orchestration Kubernetes
Les manifestes de déploiement encapsulent les meilleures pratiques pour les charges de travail en production.
*   **Haute Disponibilité :** Stratégie de mise à jour `RollingUpdate` imposée pour garantir un temps d'arrêt nul (zero downtime) pendant les déploiements.
*   **Scalabilité :** Configuration de l'`HorizontalPodAutoscaler` (HPA) pour mettre à l'échelle automatiquement les réplicas en fonction des seuils d'utilisation CPU et mémoire.
*   **Sécurité :** 
    *   Configuration stricte des `requests` et `limits` pour les ressources afin d'éviter la famine des nœuds.
    *   Système de fichiers en lecture seule (`readOnlyRootFilesystem`) imposé pour empêcher la falsification au moment de l'exécution.
    *   `ServiceAccount` et `RoleBinding` dédiés limitant l'accès à l'API Kubernetes (RBAC) en lecture seule pour les secrets nécessaires.
*   **Résilience :** `livenessProbe` et `readinessProbe` configurés pour surveiller la santé de l'API et la connectivité à la base de données.

### 5. Pipeline CI/CD DevSecOps (Jenkins)
Le pipeline impose un cheminement strict vers la production, faisant échouer le build si les standards de qualité ou de sécurité ne sont pas respectés.
1.  **Checkout :** Récupération du dernier code depuis le contrôle de version.
2.  **Build & Tests Unitaires :** Installation des dépendances et exécution des tests unitaires Jest avec génération du rapport de couverture.
3.  **Qualité du Code (SAST) :** Inspection SonarQube pour les "code smells", les vulnérabilités et les métriques de couverture.
4.  **Quality Gate :** Mise en pause du pipeline pour s'assurer que le Quality Gate de SonarQube est validé.
5.  **Build Docker :** Empaquetage de l'application Node.js.
6.  **Scan de Vulnérabilités :** Trivy scanne l'image Docker à la recherche de CVE (OS/dépendances) Critiques et Élevées.
7.  **Push vers le Registre :** Authentification sécurisée et push de l'artefact vers le registre de conteneurs.
8.  **Déploiement en Staging :** Mise à jour du manifeste Kustomize et application du déploiement de la nouvelle image sur le namespace staging de Kubernetes.
9.  **Scan de Sécurité Dynamique (DAST) :** OWASP ZAP exécute un scan de base sur le service staging nouvellement déployé.
10. **Notifications :** Intégration Slack pour un retour immédiat en cas d'échec ou de succès à l'équipe d'ingénierie.

## Pour Commencer

### Développement Local
Pour exécuter l'API localement pour le développement :
```bash
cd apps/ml-api
npm install
npm run dev
```

Pour lancer les tests unitaires et générer la couverture de code :
```bash
npm test
```

### Provisionnement de l'Infrastructure
Pour déployer l'infrastructure à l'aide de Terraform :
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Durcissement des Serveurs (Hardening)
Pour exécuter les playbooks Ansible sur l'infrastructure :
```bash
cd ansible
ansible-playbook -i inventory/production.ini site.yml
```
