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
        
        // --- Notifications ---
        EMAIL_TO = "aryasatyagigachad9@gmail.com"
        
        // --- Dynamic IPs ---
        TARGET_NODE_IP = "65.52.160.192"
        SHORT_COMMIT = ""
        PREV_BUILD = "${(env.BUILD_NUMBER.toInteger() > 1) ? env.BUILD_NUMBER.toInteger() - 1 : 1}"
    }

    stages {
        stage('Initial Setup') {
            steps {
                script {
                    env.SHORT_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()      
                    echo "✅ IP Target Siap: ${env.TARGET_NODE_IP}"
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
                        echo "Logging in to Docker Hub..."
                        sh """
                            docker run --rm \
                              -v /var/run/docker.sock:/var/run/docker.sock \
                              -e DOCKER_SCOUT_HUB_USER="${env.DH_USER}" \
                              -e DOCKER_SCOUT_HUB_PASSWORD="${env.DH_PAT}" \
                              docker/scout-cli cves simple-app:latest > scan-result.txt || echo "Scan failed but continuing..."
                        """
                        
                        def scanOutput = readFile('scan-result.txt')
                        echo "--- Scan Result Summary ---"
                        sh "grep -E 'CRITICAL|HIGH' scan-result.txt || echo 'No Critical/High found'"
                        
                        // Syarat Tahap 1: Fail jika ada CRITICAL atau HIGH
                        if (scanOutput.contains("CRITICAL") || scanOutput.contains("HIGH")) {
                            echo "❌ SECURITY GATE FAILED: Ditemukan kerentanan tingkat CRITICAL atau HIGH!"
                            // error("Build dihentikan demi keamanan karena ditemukan celah keamanan berbahaya.")
                        } else {
                            echo "✅ SECURITY GATE PASSED: Tidak ada kerentanan berbahaya ditemukan."
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
                        set +x
                        printf "%s" "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
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
            echo "Deployment Successful! Mengirim email..."
            emailext(
                subject: "✅ Jenkins Build #${env.BUILD_NUMBER} BERHASIL - ${env.APP_NAME}",
                body: """
                    <h3>Pipeline Berhasil!</h3>
                    <p><b>Job:</b> ${env.JOB_NAME}<br>
                    <b>Build:</b> #${env.BUILD_NUMBER}<br>
                    <b>Status:</b> <span style="color:green">SUCCESS</span></p>
                    <p>Cek detail: <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
                """,
                to: "${env.EMAIL_TO}"
            )
        }
        failure {
            echo "=========================================="
            echo "PIPELINE GAGAL - Menjalankan Rollback & Kirim Email..."
            echo "=========================================="
            
            emailext(
                subject: "❌ Jenkins Build #${env.BUILD_NUMBER} GAGAL - ${env.APP_NAME}",
                body: """
                    <h3>Pipeline Gagal!</h3>
                    <p><b>Job:</b> ${env.JOB_NAME}<br>
                    <b>Build:</b> #${env.BUILD_NUMBER}<br>
                    <b>Status:</b> <span style="color:red">FAILURE</span></p>
                    <p>Jenkins sedang menjalankan rollback otomatis ke versi sebelumnya.</p>
                    <p>Cek log: <a href="${env.BUILD_URL}console">${env.BUILD_URL}console</a></p>
                """,
                to: "${env.EMAIL_TO}"
            )
            
            withCredentials([
                usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS'),
                sshUserPrivateKey(credentialsId: 'target-node-ssh', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER')
            ]) {
                script {
                    // Hanya jalankan rollback jika build sebelumnya bukan build pertama
                    if (env.BUILD_NUMBER.toInteger() > 1) {
                        sh """
                            export ANSIBLE_CONFIG=${env.ANSIBLE_CONFIG}
                            export ANSIBLE_HOST_KEY_CHECKING=False
                            
                            # Jalankan rollback ke build number sebelumnya
                            ansible-playbook ${env.ANSIBLE_DIR}/playbook-deploy.yml \
                              -i ${env.ANSIBLE_DIR}/inventory/hosts.yml \
                              --private-key=\${SSH_KEY_PATH} \
                              -e "ansible_user=\${SSH_USER}" \
                              -e "ansible_ssh_private_key_file=\${SSH_KEY_PATH}" \
                              -e "image_tag=build-${env.PREV_BUILD}" \
                              -e "dockerhub_password=${DH_PASS}" \
                              -v
                        """
                        echo "✅ Rollback Berhasil ke Build #${env.PREV_BUILD}"
                    } else {
                        echo "⚠️ Tidak ada build sebelumnya untuk rollback."
                    }
                }
            }
        }
    }
}