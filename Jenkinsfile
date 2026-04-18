pipeline {
    agent any

    environment {
        APP_NAME = "simple-app"
        APP_VERSION = "1.0.0"
        SHORT_COMMIT = ""
    }

    stages {
        stage('Checkout Source') {
            steps {
                checkout scm
                script {
                    env.SHORT_COMMIT = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }
                echo "Repository checked out successfully"
                echo "Commit ID: ${env.SHORT_COMMIT}"
            }
        }

        stage('Verify Environment') {
            steps {
                sh 'docker --version'
                sh 'pwd'
                sh 'ls -la'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      -t ${APP_NAME}:${APP_VERSION} \
                      -t ${APP_NAME}:latest \
                      -t ${APP_NAME}:commit-${env.SHORT_COMMIT} .
                """
                echo "Docker image build completed"
            }
        }

        stage('List Docker Images') {
            steps {
                sh "docker images | grep ${APP_NAME} || true"
            }
        }

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

        stage('Security Gate') {
            steps {
                script {
                    def scanOutput = readFile('scan-result.txt')

                    if (scanOutput =~ /CRITICAL/) {
                        error("Build failed: Critical vulnerabilities detected in Docker image.")
                    } else {
                        echo "No High or Critical vulnerabilities detected."
                    }
                }
            }
        }

        stage('Traceability Info') {
            steps {
                script {
                    writeFile file: 'build-info.txt', text: """
Application Name : ${APP_NAME}
Application Version : ${APP_VERSION}
Jenkins Build Number : ${env.BUILD_NUMBER}
Git Commit : ${env.SHORT_COMMIT}
Docker Tags :
- ${APP_NAME}:${APP_VERSION}
- ${APP_NAME}:latest
- ${APP_NAME}:commit-${env.SHORT_COMMIT}
Build Time : ${new Date().toString()}
"""
                }
                sh 'cat build-info.txt'
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully"
            archiveArtifacts artifacts: 'build-info.txt, scan-result.txt', fingerprint: true
        }
        failure {
            echo "Pipeline failed"
            archiveArtifacts artifacts: 'build-info.txt, scan-result.txt', fingerprint: true, allowEmptyArchive: true
        }
        always {
            echo "Pipeline finished"
        }
    }
}