pipeline {
    agent any

    environment {
        // DockerHub image details
        DOCKERHUB_REGISTRY = "docker.io"
        DOCKERHUB_NAMESPACE = "your-dockerhub-namespace"
        IMAGE_NAME = "your-app"
        IMAGE_TAG = "latest"

        // Credentials ID created in Jenkins for DockerHub login
        DOCKER_CREDS = "dockerhub-credentials"
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Sopuru/jenkins-pipeline.git'
            }
        }

        stage('Build & Push with Kaniko') {
            agent {
                docker {
                    // Official Kaniko executor image
                    image 'gcr.io/kaniko-project/executor:latest'
                    args '--entrypoint=""'
                }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CREDS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        mkdir -p /kaniko/.docker
                        cat > /kaniko/.docker/config.json <<EOF
                        {
                          "auths": {
                            "${DOCKERHUB_REGISTRY}": {
                              "username": "${DOCKER_USER}",
                              "password": "${DOCKER_PASS}"
                            }
                          }
                        }
                        EOF

                        /kaniko/executor \
                          --context `pwd` \
                          --dockerfile `pwd`/Dockerfile \
                          --destination ${DOCKERHUB_REGISTRY}/${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} \
                          --cleanup
                    '''
                }
            }
        }

        stage('Anchore Scan') {
            steps {
                anchore name: 'anchore_scan', 
                        image: "${DOCKERHUB_REGISTRY}/${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}", 
                        forceAnalyze: true, 
                        bailOnFail: false, 
                        timeout: 600
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
    }
}
