pipeline {
    agent any

    environment {
        REGISTRY = "docker.io"
        IMAGE_NAME = "your-dockerhub-username/your-image"
        TAG = "latest"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Docker Build') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${TAG}")
                }
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([kubeconfigFile(credentialsId: 'regcred', variable: 'KUBECONFIG')]) {
                    sh '''
                        echo "Logging in to DockerHub..."
                        echo $DOCKER_CONFIG_JSON | base64 -d > /tmp/config.json
                        export DOCKER_CONFIG=/tmp
                        docker login -u $(jq -r '.auths["https://index.docker.io/v1/"].username' /tmp/config.json) \
                                     -p $(jq -r '.auths["https://index.docker.io/v1/"].password' /tmp/config.json)
                    '''
                }
            }
        }

        stage('Push Image') {
            steps {
                script {
                    sh "docker push ${IMAGE_NAME}:${TAG}"
                }
            }
        }

        stage('Anchore Scan') {
            steps {
                script {
                    // Anchore plugin step (make sure Anchore plugin is installed in Jenkins)
                    anchore name: "${IMAGE_NAME}:${TAG}", 
                            policyBundleId: '', 
                            bailOnFail: true
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout'
        }
        success {
            echo "✅ Build, Push & Scan completed successfully!"
        }
        failure {
            echo "❌ Build or Scan failed!"
        }
    }
}
