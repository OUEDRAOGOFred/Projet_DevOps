pipeline {
    agent any
    
    // Définition de variables d'environnement globales
    environment {
        DOCKER_IMAGE = "ml-api"
        DOCKER_REGISTRY = "registry.example.com"
        IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
        KUBECONFIG = credentials('k8s-kubeconfig-staging') // Stocké de manière sécurisée hors du code
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Build & Unit Tests') {
            steps {
                dir('apps/ml-api') {
                    sh '''
                    npm ci
                    npm test
                    '''
                }
            }
            post {
                always {
                    junit 'apps/ml-api/junit.xml'
                }
            }
        }

        stage('Code Quality (SonarQube)') {
            steps {
                // Utilisation de l'intégration SonarQube pour le scan SAST (Sécurité et Qualité)
                withSonarQubeEnv('SonarQube-Server') {
                    dir('apps/ml-api') {
                        sh 'sonar-scanner -Dsonar.projectKey=ml-api -Dsonar.sources=src/'
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // Vérifie que la qualité du code respecte la politique établie, sinon coupe le pipe
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Docker Build') {
            steps {
                dir('apps/ml-api') {
                    sh "docker build -t ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Vulnerability Scan (Trivy)') {
            steps {
                // Scan de l'image Docker pour détecter d'éventuelles failles OS ou de dépendances (CVE)
                sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}"
            }
        }

        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-registry-creds', usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                    sh '''
                    echo $REG_PASS | docker login ${DOCKER_REGISTRY} -u $REG_USER --password-stdin
                    docker push ${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('Deploy to K8s (Staging)') {
            steps {
                // Déploiement en utilisant Kustomize avec application de l'image fraîchement buildée
                sh '''
                cd k8s/overlays/staging
                kustomize edit set image ml-api-image=${DOCKER_REGISTRY}/${DOCKER_IMAGE}:${IMAGE_TAG}
                kubectl apply -k . --kubeconfig $KUBECONFIG
                '''
            }
        }

        stage('Dynamic Security Scan (DAST - ZAP)') {
            steps {
                // Scan dynamique de la sécurité sur l'environnement de staging déployé avec OWASP ZAP
                // Cela valide l'exigence "Scan dynamique" du projet
                sh '''
                docker run -t owasp/zap2docker-stable zap-baseline.py \
                  -t http://ml-api-svc.ml-staging.svc.cluster.local:80 \
                  -r zap-report.html || true
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'zap-report.html', allowEmptyArchive: true
                }
            }
        }
    }
    
    post {
        failure {
            // Notifier l'équipe SecOps/DevOps en cas de faille détectée ou d'erreur
            slackSend(color: 'danger', message: "Pipeline Failed: ${env.JOB_NAME} [${env.BUILD_NUMBER}]")
        }
        success {
            slackSend(color: 'good', message: "Pipeline Succeeded ! New ML API deployed to Staging. [${env.BUILD_NUMBER}]")
        }
    }
}
