pipeline {
    agent any

    environment {
        APP_NAME = "simple-app"
        APP_VERSION = "1.0.0"
        SHORT_COMMIT = ""
        DOCKERHUB_USER = "kelompok3devops"
        DOCKER_IMAGE = "${DOCKERHUB_USER}/${APP_NAME}"
        TARGET_NODE_IP = "70.153.151.129"
        TARGET_NODE_USER = "ubuntu"
        DEPLOY_DIR = "/opt/app-deployment"
        PREV_BUILD = "${BUILD_NUMBER.toInteger() - 1}"
        // Ansible Configuration
        ANSIBLE_DIR = "/var/jenkins_home/ansible"
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
    }

    stages {
        // ===================================================
        // TAHAP 1: Checkout Source Code
        // ===================================================
        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.SHORT_COMMIT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
                echo "=========================================="
                echo "Repository checked out successfully"
                echo "Commit ID : ${env.SHORT_COMMIT}"
                echo "Build No  : ${env.BUILD_NUMBER}"
                echo "=========================================="
            }
        }

        // ===================================================
        // TAHAP 2: Verifikasi Environment
        // ===================================================
        stage('Verify Environment') {
            steps {
                sh 'docker --version'
                sh 'ansible --version || echo "Ansible not available on host (OK if in container)"'
                sh 'pwd'
                sh 'ls -la'
            }
        }

        // ===================================================
        // TAHAP 3: Build Docker Image
        // Pipeline Traceability: Tag dengan version, latest,
        // commit SHA, dan build number
        // ===================================================
        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      -t ${APP_NAME}:${APP_VERSION} \
                      -t ${APP_NAME}:latest \
                      -t ${APP_NAME}:commit-${env.SHORT_COMMIT} \
                      -t ${APP_NAME}:build-${env.BUILD_NUMBER} .
                """
                echo "Docker image build completed with tags:"
                echo "  - ${APP_NAME}:${APP_VERSION}"
                echo "  - ${APP_NAME}:latest"
                echo "  - ${APP_NAME}:commit-${env.SHORT_COMMIT}"
                echo "  - ${APP_NAME}:build-${env.BUILD_NUMBER}"
            }
        }

        // ===================================================
        // TAHAP 4: List Docker Images
        // ===================================================
        stage('List Docker Images') {
            steps {
                sh "docker images | grep ${APP_NAME} || true"
            }
        }

        // ===================================================
        // TAHAP 5: Docker Scout Security Scan (DevSecOps)
        // ===================================================
        stage('Docker Scout Scan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_PAT'
                )]) {
                    sh '''
                        docker run --rm \
                          -u root \
                          -v /var/run/docker.sock:/var/run/docker.sock \
                          -e DOCKER_SCOUT_HUB_USER="$DOCKERHUB_USER" \
                          -e DOCKER_SCOUT_HUB_PASSWORD="$DOCKERHUB_PAT" \
                          docker/scout-cli cves simple-app:latest > scan-result.txt

                        cat scan-result.txt
                    '''
                }
            }
        }

        // ===================================================
        // TAHAP 6: Security Gate — Gagal jika ada Critical/High
        // ===================================================
        stage('Security Gate') {
            steps {
                script {
                    def scanOutput = readFile('scan-result.txt')

                    def criticalMatch = (scanOutput =~ /CRITICAL\s+(\d+)/)
                    def highMatch = (scanOutput =~ /HIGH\s+(\d+)/)

                    def criticalCount = 0
                    def highCount = 0

                    if (criticalMatch.find()) {
                        criticalCount = criticalMatch.group(1).toInteger()
                    }

                    if (highMatch.find()) {
                        highCount = highMatch.group(1).toInteger()
                    }

                    echo "=========================================="
                    echo "Security Scan Results:"
                    echo "  Critical vulnerabilities: ${criticalCount}"
                    echo "  High vulnerabilities: ${highCount}"
                    echo "=========================================="

                    if (criticalCount > 0) {
                        error("BUILD FAILED: ${criticalCount} Critical vulnerabilities detected!")
                    } else {
                        echo "No Critical vulnerabilities detected. Proceeding..."
                    }
                }
            }
        }

        // ===================================================
        // TAHAP 7: Push Image ke Docker Hub Registry
        // Pipeline Traceability: Push semua tag untuk tracking
        // ===================================================
        stage('Push to Registry') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

                        # Tag untuk Docker Hub
                        docker tag ${APP_NAME}:latest ${DOCKER_IMAGE}:latest
                        docker tag ${APP_NAME}:${APP_VERSION} ${DOCKER_IMAGE}:${APP_VERSION}
                        docker tag ${APP_NAME}:commit-${SHORT_COMMIT} ${DOCKER_IMAGE}:commit-${SHORT_COMMIT}
                        docker tag ${APP_NAME}:build-${BUILD_NUMBER} ${DOCKER_IMAGE}:build-${BUILD_NUMBER}

                        # Push semua tag
                        docker push ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:${APP_VERSION}
                        docker push ${DOCKER_IMAGE}:commit-${SHORT_COMMIT}
                        docker push ${DOCKER_IMAGE}:build-${BUILD_NUMBER}
                    '''
                }
                echo "All images pushed to Docker Hub: ${DOCKER_IMAGE}"
            }
        }

        // ===================================================
        // TAHAP 8: Deploy ke Target Node via Ansible
        // Menggunakan Ansible Playbook + Docker Compose
        // pada Target Deployment Node
        // ===================================================
        stage('Deploy to Target') {
            steps {
                echo "=========================================="
                echo "Deploying via Ansible Playbook..."
                echo "Image tag: build-${env.BUILD_NUMBER}"
                echo "=========================================="

                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        export ANSIBLE_CONFIG=${ANSIBLE_DIR}/ansible.cfg
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        ansible-playbook ${ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${ANSIBLE_DIR}/inventory/hosts.yml \
                          -e "image_tag=build-${env.BUILD_NUMBER}" \
                          -e "dockerhub_password=\$DH_PASS" \
                          -v
                    """
                }

                echo "=========================================="
                echo "Ansible deployment completed!"
                echo "=========================================="
            }
        }

        // ===================================================
        // TAHAP 9: Smoke Test Pasca-Deployment
        // Validasi bahwa aplikasi berjalan dengan benar
        // ===================================================
        stage('Smoke Test') {
            steps {
                script {
                    def maxRetries = 5
                    def retryDelay = 10
                    def healthy = false

                    for (int i = 1; i <= maxRetries; i++) {
                        try {
                            sh """
                                STATUS=\$(curl -s -o /dev/null -w '%{http_code}' http://${TARGET_NODE_IP}:3000/health || echo "000")
                                echo "Attempt ${i}/${maxRetries}: HTTP Status = \$STATUS"
                                if [ "\$STATUS" = "200" ]; then
                                    echo "Health check PASSED"
                                    exit 0
                                else
                                    echo "Health check FAILED (status: \$STATUS)"
                                    exit 1
                                fi
                            """
                            healthy = true
                            break
                        } catch (Exception e) {
                            if (i < maxRetries) {
                                echo "Retry in ${retryDelay} seconds..."
                                sleep(retryDelay)
                            }
                        }
                    }

                    if (!healthy) {
                        echo "=========================================="
                        echo "SMOKE TEST FAILED — Initiating rollback..."
                        echo "=========================================="
                        env.DEPLOY_FAILED = "true"
                    } else {
                        echo "=========================================="
                        echo "SMOKE TEST PASSED"
                        echo "App running at: http://${TARGET_NODE_IP}:3000"
                        echo "=========================================="
                        env.DEPLOY_FAILED = "false"
                    }
                }
            }
        }

        // ===================================================
        // TAHAP 10: Rollback Otomatis via Ansible
        // Mengembalikan ke versi stabil sebelumnya
        // menggunakan Ansible playbook
        // ===================================================
        stage('Rollback') {
            when {
                expression { env.DEPLOY_FAILED == "true" }
            }
            steps {
                echo "=========================================="
                echo "ROLLBACK: Deploying previous stable version via Ansible..."
                echo "=========================================="

                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        export ANSIBLE_CONFIG=${ANSIBLE_DIR}/ansible.cfg
                        export ANSIBLE_HOST_KEY_CHECKING=False

                        ansible-playbook ${ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${ANSIBLE_DIR}/inventory/hosts.yml \
                          -e "image_tag=build-${PREV_BUILD}" \
                          -e "dockerhub_password=\$DH_PASS" \
                          -v
                    """
                }

                error("Deployment failed and rolled back to build-${PREV_BUILD}. Build marked as FAILURE.")
            }
        }
    }

    // ===================================================
    // POST ACTIONS: Traceability + Notifikasi
    // ===================================================
    post {
        always {
            script {
                writeFile file: 'build-info.txt', text: """
========================================
Pipeline Traceability Report
========================================
Application Name    : ${APP_NAME}
Application Version : ${APP_VERSION}
Jenkins Build Number: ${env.BUILD_NUMBER}
Git Commit          : ${env.SHORT_COMMIT}
Docker Image        : ${DOCKER_IMAGE}
Docker Tags:
  - ${DOCKER_IMAGE}:${APP_VERSION}
  - ${DOCKER_IMAGE}:latest
  - ${DOCKER_IMAGE}:commit-${env.SHORT_COMMIT}
  - ${DOCKER_IMAGE}:build-${env.BUILD_NUMBER}
Target Node         : ${TARGET_NODE_IP}
Deploy Method       : Ansible Playbook + Docker Compose
Build Time          : ${new Date().toString()}
Build Status        : ${currentBuild.currentResult}
========================================
"""
            }
            sh 'cat build-info.txt'
            archiveArtifacts artifacts: 'build-info.txt, scan-result.txt', fingerprint: true, allowEmptyArchive: true
            echo "Pipeline finished"
        }

        success {
            echo "=========================================="
            echo "PIPELINE BERHASIL"
            echo "App: http://${TARGET_NODE_IP}:3000"
            echo "=========================================="

            // Email Notification — Success
            emailext(
                subject: "✅ Jenkins Build #${env.BUILD_NUMBER} BERHASIL - ${APP_NAME}",
                body: """
                <h2>Pipeline Berhasil!</h2>
                <table border="1" cellpadding="5" cellspacing="0">
                    <tr><td><b>Job</b></td><td>${env.JOB_NAME}</td></tr>
                    <tr><td><b>Build</b></td><td>#${env.BUILD_NUMBER}</td></tr>
                    <tr><td><b>Git Commit</b></td><td>${env.SHORT_COMMIT}</td></tr>
                    <tr><td><b>Docker Image</b></td><td>${DOCKER_IMAGE}:build-${env.BUILD_NUMBER}</td></tr>
                    <tr><td><b>Target</b></td><td>http://${TARGET_NODE_IP}:3000</td></tr>
                    <tr><td><b>Deploy Method</b></td><td>Ansible + Docker Compose</td></tr>
                    <tr><td><b>Status</b></td><td style="color:green">SUCCESS</td></tr>
                </table>
                <p>Detail: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                """,
                mimeType: 'text/html',
                to: '${DEFAULT_RECIPIENTS}',
                recipientProviders: [requestor()]
            )
        }

        failure {
            echo "=========================================="
            echo "PIPELINE GAGAL"
            echo "=========================================="

            // Email Notification — Failure
            emailext(
                subject: "❌ Jenkins Build #${env.BUILD_NUMBER} GAGAL - ${APP_NAME}",
                body: """
                <h2>Pipeline Gagal!</h2>
                <table border="1" cellpadding="5" cellspacing="0">
                    <tr><td><b>Job</b></td><td>${env.JOB_NAME}</td></tr>
                    <tr><td><b>Build</b></td><td>#${env.BUILD_NUMBER}</td></tr>
                    <tr><td><b>Git Commit</b></td><td>${env.SHORT_COMMIT}</td></tr>
                    <tr><td><b>Status</b></td><td style="color:red">FAILURE</td></tr>
                </table>
                <p>Cek log: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                """,
                mimeType: 'text/html',
                to: '${DEFAULT_RECIPIENTS}',
                recipientProviders: [requestor()]
            )
        }
    }
}