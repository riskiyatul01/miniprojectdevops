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

                    // Mencari IP Target di inventory
                    def inventoryPath = "${ANSIBLE_DIR}/inventory/hosts.yml"
                    echo "Mencari inventory di: ${inventoryPath}"
                    
                    if (fileExists(inventoryPath)) {
                        def fileContent = sh(script: "cat ${inventoryPath}", returnStdout: true)
                        echo "Isi Inventory:\n${fileContent}"
                        
                        // Cara paling simpel dan pasti pakai shell grep
                        def ip = sh(
                            script: "grep -A 1 'target-node:' ${inventoryPath} | grep 'ansible_host:' | awk '{print \$2}'",
                            returnStdout: true
                        ).trim()

                        if (ip) {
                            env.TARGET_NODE_IP = ip
                            echo "✅ IP Target Ditemukan: ${env.TARGET_NODE_IP}"
                        } else {
                            // Fallback: Cari IP apa saja di file itu
                            def fallbackMatch = (fileContent =~ /([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/)
                            if (fallbackMatch.find()) {
                                env.TARGET_NODE_IP = fallbackMatch.group(1)
                                echo "⚠️ IP Ditemukan via Fallback: ${env.TARGET_NODE_IP}"
                            } else {
                                error "Format IP tidak ditemukan di hosts.yml"
                            }
                        }
                    } else {
                        error "File inventory TIDAK DITEMUKAN di ${inventoryPath}. Pastikan kamu sudah jalankan ansible-playbook dari laptop!"
                    }
                }
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
                withCredentials([
                    usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS'),
                    sshUserPrivateKey(credentialsId: 'target-node-ssh', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER')
                ]) {
                    sh """
                        set -x
                        export ANSIBLE_CONFIG=${env.ANSIBLE_CONFIG}
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        
                        ansible-playbook ${env.ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${env.ANSIBLE_DIR}/inventory/hosts.yml \
                          --private-key=\${SSH_KEY_PATH} \
                          -e "ansible_user=\${SSH_USER}" \
                          -e "ansible_ssh_private_key_file=\${SSH_KEY_PATH}" \
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