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

                    def inventoryPath = "${ANSIBLE_DIR}/inventory/hosts.yml"
                    echo "Mencari inventory di: ${inventoryPath}"
                    
                    if (fileExists(inventoryPath)) {
                        // Gunakan Python untuk mencari IP setelah kata 'target-node'
                        // Cara ini jauh lebih kuat daripada grep/sed
                        def pythonCmd = """
import re
import sys
try:
    with open('${inventoryPath}', 'r') as f:
        content = f.read()
        # Mencari pola target-node lalu mengambil IP pertama setelahnya
        match = re.search(r'target-node:.*?ansible_host:\\s*([0-9.]+)', content, re.DOTALL)
        if match:
            print(match.group(1))
        else:
            # Fallback: ambil IP terakhir di file jika target-node spesifik gagal
            ips = re.findall(r'[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}', content)
            if ips:
                print(ips[-1])
except Exception as e:
    pass
"""
                        def ip = sh(script: "python3 -c \"${pythonCmd}\" || python -c \"${pythonCmd}\"", returnStdout: true).trim()

                        if (ip && ip != "" && ip != "None") {
                            env.TARGET_NODE_IP = ip
                            echo "✅ IP Target Berhasil Diekstrak: ${env.TARGET_NODE_IP}"
                        } else {
                            error "Gagal mengekstrak IP! Isi file inventory tidak dikenali."
                        }
                    } else {
                        error "File inventory tidak ditemukan di ${inventoryPath}!"
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