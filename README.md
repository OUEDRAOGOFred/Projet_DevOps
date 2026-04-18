# Predictive Analytics API - DevSecOps Architecture

## Overview

This repository contains the source code, infrastructure definitions, and automation scripts for a highly secure, scalable Machine Learning Predictive Analytics API. The project is designed with a strict DevSecOps approach, ensuring security is integrated at every stage of the software development lifecycle (SDLC).

The backend is built with Node.js and relies on a pure SQL implementation for database interactions, deployed on a managed Kubernetes cluster.

## Architecture and Technology Stack

The project utilizes the following technology stack to achieve a resilient and secure architecture:

*   **Application Backend:** Node.js, Express, Jest, Supertest
*   **Database:** PostgreSQL (Cloud RDS)
*   **Containerization:** Docker (Multi-stage builds)
*   **CI/CD Automation:** Jenkins (Declarative Pipeline)
*   **Continuous Inspection & Security:** SonarQube (SAST), Trivy (Container Scanning), OWASP ZAP (DAST)
*   **Orchestration:** Kubernetes (Deployment, Service, HPA, RBAC, NetworkPolicies)
*   **Infrastructure as Code (IaC):** Terraform (Huawei Cloud Provider)
*   **Configuration Management:** Ansible

## Repository Structure

The monorepo is organized to clearly separate application code from infrastructure and deployment rules:

```text
.
├── apps/
│   └── ml-api/                  # Node.js API source code, tests, and Dockerfile
├── k8s/
│   └── base/                    # Kubernetes manifests (Deployment, HPA, Service, RBAC)
├── terraform/                   # Terraform IaC for Huawei Cloud (CCE, RDS, Networking)
├── ansible/                     # Ansible Playbooks and Roles (Security hardening, K8s config)
├── Jenkinsfile                  # Declarative DevSecOps CI/CD Pipeline definition
└── sonar-project.properties     # SonarQube configuration for SAST
```

## Detailed Component Specifications

### 1. Infrastructure as Code (Terraform)
The infrastructure is provisioned using Terraform on Huawei Cloud.
*   **State Management:** State files are securely stored remotely on Object Storage (OBS) to prevent local secrets exposure and allow team collaboration.
*   **Networking:** VPC separation with strict Security Groups. The RDS PostgreSQL instance does not have public access and accepts inbound traffic exclusively from the Kubernetes cluster (CCE) nodes.
*   **Compute:** Managed Kubernetes Cluster (CCE v3) with auto-scaling node pools running hardened EulerOS.

### 2. Configuration Management (Ansible)
Ansible is used to enforce Node-level and Cluster-level configurations idempotently.
*   **security-hardening role:** Enforces CIS benchmark standards on cluster nodes (Disabling root SSH login, enforcing public key authentication, hardening kernel sysctl parameters against network attacks, and installing auditd).
*   **k8s-config role:** Automates the creation of staging/production namespaces and establishes a Zero Trust network environment by deploying a default "deny-all" NetworkPolicy.

### 3. Application Security & Containerization (Docker)
The Node.js API is packaged via a highly optimized Dockerfile.
*   **Multi-stage Build:** Utilizes `node:20-alpine` as a base, compiling code and pruning development dependencies (`npm prune --production`) before transferring the final artifact to the production image.
*   **Least Privilege:** The container runs under a non-root user (`node` with UID 1000).
*   **Deterministic Builds:** Uses `npm ci --ignore-scripts` to prevent supply chain attacks via unauthorized post-install scripts.

### 4. Kubernetes Orchestration
The deployment manifests encapsulate best practices for production workloads.
*   **High Availability:** Enforced `RollingUpdate` strategy to ensure zero downtime during deployments.
*   **Scalability:** Configured `HorizontalPodAutoscaler` (HPA) to automatically scale replicas based on CPU and memory utilization thresholds.
*   **Security:** 
    *   Strict `requests` and `limits` configuration for resources to prevent node starvation.
    *   `readOnlyRootFilesystem` enforced to prevent runtime tampering.
    *   Dedicated `ServiceAccount` and `RoleBinding` restricting Kubernetes API access (RBAC) to read-only for necessary secrets.
*   **Resilience:** Configured `livenessProbe` and `readinessProbe` to monitor API health and database connectivity.

### 5. DevSecOps CI/CD Pipeline (Jenkins)
The pipeline dictates a strict pathway to production, failing the build if quality or security standards are unmet.
1.  **Checkout:** Retrieves the latest code from version control.
2.  **Build & Unit Tests:** Installs dependencies and runs Jest unit tests with coverage reporting.
3.  **Code Quality (SAST):** SonarQube inspection for code smells, vulnerabilities, and coverage metrics.
4.  **Quality Gate:** Pauses the pipeline to ensure the SonarQube Quality Gate passes.
5.  **Docker Build:** Packages the Node.js application.
6.  **Vulnerability Scan:** Trivy scans the Docker image for Critical and High OS/dependency CVEs.
7.  **Push to Registry:** Securely authenticate and push the artifact to the container registry.
8.  **Deploy to Staging:** Updates the Kustomize manifest and applies the new image deployment to the Kubernetes staging namespace.
9.  **Dynamic Security Scan (DAST):** OWASP ZAP executes a baseline scan against the newly deployed staging service.
10. **Notifications:** Slack integration for immediate failure or success feedback to the engineering team.

## Getting Started

### Local Development
To run the API locally for development:
```bash
cd apps/ml-api
npm install
npm run dev
```

To run unit tests and generate coverage:
```bash
npm test
```

### Infrastructure Provisioning
To deploy the infrastructure using Terraform:
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Server Hardening
To run the Ansible playbooks against the infrastructure:
```bash
cd ansible
ansible-playbook -i inventory/production.ini site.yml
```
