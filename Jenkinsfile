pipeline {
    agent any

    environment {
        // --- Centralized Config ---
        APP_NAME = "simple-app"
        APP_VERSION = "1.0.0"
        DOCKERHUB_USER = "ax3lrod"
        DOCKER_IMAGE = "${DOCKERHUB_USER}/${APP_NAME}"
        TARGET_NODE_USER = "ubuntu"
        DEPLOY_DIR = "/opt/app-deployment"
        
        // --- Ansible Config ---
        ANSIBLE_DIR = "/var/jenkins_home/ansible"
        ANSIBLE_CONFIG = "${ANSIBLE_DIR}/ansible.cfg"
        
        // --- Dynamic IPs (Extracted in stages) ---
        TARGET_NODE_IP = ""
        SHORT_COMMIT = ""
    }

    stages {
        stage('Initial Setup') {
            steps {
                script {
                    env.SHORT_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    
                    // Ekstrak IP otomatis dari inventory agar tidak hardcoded
                    try {
                        env.TARGET_NODE_IP = sh(
                            script: "grep -A 2 'target-node:' ${ANSIBLE_DIR}/inventory/hosts.yml | grep 'ansible_host:' | awk '{print \$2}' | tr -d ' '",
                            returnStdout: true
                        ).trim()
                    } catch (e) {
                        echo "Warning: Gagal ekstrak IP dari inventory, fallback ke localhost atau periksa file inventory."
                    }
                }
                echo "Building: ${env.DOCKER_IMAGE}:${env.APP_VERSION}"
                echo "Target IP: ${env.TARGET_NODE_IP}"
            }
        }

        stage('Verify Environment') {
            steps {
                sh 'docker --version'
                sh 'ansible --version || echo "Ansible via Docker Exec available"'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      -t ${APP_NAME}:latest \
                      -t ${DOCKER_IMAGE}:latest \
                      -t ${DOCKER_IMAGE}:build-${env.BUILD_NUMBER} .
                """
            }
        }

        stage('Docker Scout Security Scan') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PAT'
                )]) {
                    script {
                        // Pastikan menggunakan DH_USER (hasil dari withCredentials) bukan DOCKERHUB_USER hardcoded
                        echo "Logging in to Docker Hub for Scout as ${env.DH_USER}..."
                        sh """
                            echo "${env.DH_PAT}" | docker login -u "${env.DH_USER}" --password-stdin
                            docker run --rm \
                              -v /var/run/docker.sock:/var/run/docker.sock \
                              -e DOCKER_SCOUT_HUB_USER="${env.DH_USER}" \
                              -e DOCKER_SCOUT_HUB_PASSWORD="${env.DH_PAT}" \
                              docker/scout-cli cves simple-app:latest > scan-result.txt || echo "Scan failed but continuing..."
                        """
                        
                        def scanOutput = readFile('scan-result.txt')
                        echo "--- Scan Result Summary ---"
                        sh "grep -E 'CRITICAL|HIGH' scan-result.txt || echo 'No Critical/High found'"
                        
                        // Check for CRITICAL vulnerabilities
                        if (scanOutput.contains("CRITICAL")) {
                            echo "⚠️ CRITICAL Vulnerabilities found!"
                            // Uncomment line below if you want to strictly block on Critical
                            // error("Build stopped due to Critical vulnerabilities")
                        }
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:build-${env.BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Deploy via Ansible') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        export ANSIBLE_CONFIG=${env.ANSIBLE_CONFIG}
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        
                        ansible-playbook ${env.ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${env.ANSIBLE_DIR}/inventory/hosts.yml \
                          -e "image_tag=build-${env.BUILD_NUMBER}" \
                          -e "dockerhub_password=${DH_PASS}" \
                          -v
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    def success = false
                    for (int i = 0; i < 5; i++) {
                        try {
                            sh "curl -s -f http://${env.TARGET_NODE_IP}:3000/health"
                            success = true
                            break
                        } catch (e) {
                            echo "Attempt ${i+1}: App not ready, waiting..."
                            sleep 10
                        }
                    }
                    if (!success) {
                        env.DEPLOY_FAILED = "true"
                        error "Smoke test failed after 5 attempts"
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'scan-result.txt', allowEmptyArchive: true
        }
        success {
            echo "Deployment Successful!"
        }
        failure {
            echo "Deployment Failed. Check logs."
        }
    }
}
