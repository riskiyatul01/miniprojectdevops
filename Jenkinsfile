pipeline {
    agent any

    environment {
        APP_NAME        = "simple-app"
        APP_VERSION     = "1.0.0"
        DOCKERHUB_USER  = "fioreenza"
        TARGET_NODE_IP  = "70.153.151.129"
        DOCKER_IMAGE    = "${DOCKERHUB_USER}/${APP_NAME}"
        
        // Lokasi Ansible di server Jenkins Anda
        ANSIBLE_DIR     = "/var/jenkins_home/ansible"
        
        // Menghitung build sebelumnya untuk rollback
        PREV_BUILD      = "${env.BUILD_NUMBER.toInteger() > 1 ? env.BUILD_NUMBER.toInteger() - 1 : 1}"
        SHORT_COMMIT    = ""
    }

    stages {
        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.SHORT_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      -t ${APP_NAME}:latest \
                      -t ${APP_NAME}:build-${env.BUILD_NUMBER} .
                """
            }
        }

        stage('Docker Scout Scan') {
            steps {
                // Memanggil Brankas Jenkins
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        
                        docker run --rm \
                            -v /var/run/docker.sock:/var/run/docker.sock \
                            docker/scout-cli cves ${APP_NAME}:latest > scan-result.txt
                    '''
                }
            }
        }

        stage('Security Gate') {
            steps {
                script {
                    // Baca file hasil scan dari stage sebelumnya
                    def scanOutput = readFile('scan-result.txt')

                    // Cari angka setelah kata CRITICAL dan HIGH menggunakan Regex
                    def criticalMatch = (scanOutput =~ /CRITICAL\s+(\d+)/)
                    def highMatch = (scanOutput =~ /HIGH\s+(\d+)/)

                    // Jika ketemu ambil angkanya, jika tidak anggap 0
                    def criticalCount = criticalMatch.find() ? criticalMatch.group(1).toInteger() : 0
                    def highCount = highMatch.find() ? highMatch.group(1).toInteger() : 0

                    echo "=========================================="
                    echo "Hasil Scan Keamanan:"
                    echo "  Critical: ${criticalCount}"
                    echo "  High    : ${highCount}"
                    echo "=========================================="

                    // LOGIKA: Jika Critical > 0 ATAU High > 0, maka GAGALKAN build
                    if (criticalCount > 0 || highCount > 0) {
                        error("BUILD STOPPED: Ditemukan ${criticalCount} Critical dan ${highCount} High vulnerabilities!")
                    } else {
                        echo "Keamanan aman (0 Critical, 0 High). Melanjutkan ke tahap Push..."
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        
                        # Tag ulang image lokal ke format Docker Hub
                        docker tag ${APP_NAME}:latest ${DOCKER_IMAGE}:latest
                        docker tag ${APP_NAME}:build-${BUILD_NUMBER} ${DOCKER_IMAGE}:build-${BUILD_NUMBER}
                        
                        # Push ke Cloud
                        docker push ${DOCKER_IMAGE}:latest
                        docker push ${DOCKER_IMAGE}:build-${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Deploy with Ansible') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    sh """
                        export ANSIBLE_HOST_KEY_CHECKING=False
                        ansible-playbook ${ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${ANSIBLE_DIR}/inventory/hosts.yml \
                          -e "image_tag=build-${BUILD_NUMBER}" \
                          -e "dockerhub_user=${DH_USER}" \
                          -e "dockerhub_password=${DH_PASS}"
                    """
                }
            }
        }

        stage('Smoke Test') {
            steps {
                script {
                    // Cek apakah aplikasi jalan (tunggu 10 detik dulu)
                    sleep 10
                    try {
                        sh "curl -f http://${TARGET_NODE_IP}:3000/health"
                        env.DEPLOY_FAILED = "false"
                    } catch (Exception e) {
                        env.DEPLOY_FAILED = "true"
                        error("Aplikasi tidak merespon!")
                    }
                }
            }
        }

        stage('Rollback') {
            when {
                expression { env.DEPLOY_FAILED == "true" }
            }
            steps {
                echo "Melakukan Rollback ke build #${PREV_BUILD}"
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
                    sh """
                        ansible-playbook ${ANSIBLE_DIR}/playbook-deploy.yml \
                          -i ${ANSIBLE_DIR}/inventory/hosts.yml \
                          -e "image_tag=build-${PREV_BUILD}" \
                          -e "dockerhub_password=${DH_PASS}"
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline Berhasil!"
        }
        failure {
            echo "Pipeline Gagal!"
        }
    }
}