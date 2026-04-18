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

            echo "===== SCAN RESULT START ====="
            echo scanOutput
            echo "===== SCAN RESULT END ====="

            def criticalMatch = (scanOutput =~ /CRITICAL\\s+(\\d+)/)
            def highMatch = (scanOutput =~ /HIGH\\s+(\\d+)/)

            def criticalCount = 0
            def highCount = 0

            if (criticalMatch.find()) {
                criticalCount = criticalMatch.group(1).toInteger()
            }

            if (highMatch.find()) {
                highCount = highMatch.group(1).toInteger()
            }

            echo "Critical vulnerabilities: ${criticalCount}"
            echo "High vulnerabilities: ${highCount}"

            if (criticalCount > 0 || highCount > 0) {
                error("Build failed: High or Critical vulnerabilities detected in Docker image.")
            } else {
                echo "No High or Critical vulnerabilities detected."
            }
        }
    }
}

    post {
        always {
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
            archiveArtifacts artifacts: 'build-info.txt, scan-result.txt', fingerprint: true, allowEmptyArchive: true
            echo "Pipeline finished"
        }

        success {
            echo "Pipeline completed successfully"
        }

        failure {
            echo "Pipeline failed"
        }
    }
}