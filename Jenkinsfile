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

        // Full image name for Anchore to scan
        FULL_IMAGE = "${DOCKERHUB_REGISTRY}/${DOCKERHUB_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"
        ANCHORE_FILE_NAME = "anchore_images.txt"
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
                          --destination ${FULL_IMAGE} \
                          --cleanup
                    '''
                }
            }
        }

        stage('Anchore Scan') {
            steps {
                // Create a file for the Anchore plugin to read
                sh "echo '${FULL_IMAGE}' > ${ANCHORE_FILE_NAME}"

                // Now call the Anchore step with the correct 'name' parameter
                anchore name: "${ANCHORE_FILE_NAME}",
                        bailOnFail: false
            }
        }
    }

    post {
        always {
            echo 'Pipeline finished.'
        }
    }
}
