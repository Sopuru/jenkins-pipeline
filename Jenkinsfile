// Jenkinsfile for Docker Image Build and Anchore Scanning with Kaniko on K8s

pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins/label: kaniko-builder
spec:
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:alpine
      tty: true
    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      tty: true
      command:
        - cat
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
        - name: workspace
          mountPath: /workspace
  volumes:
    - name: docker-config
      secret:
        secretName: docker-config
    - name: workspace
      emptyDir: {}
"""
            defaultContainer 'jnlp'
        }
    }

    environment {
        DOCKER_IMAGE_NAME = "joshua"
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}"
        FULL_DOCKER_IMAGE = "sopuru24/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}"
        ANCHORECTL_URL = "https://anchore.nizati.com/"
        ANCHORE_POLICY = "Anchore Enterprise - Secure v20250101"
        ANCHORECTL_VERSION = "v5.18.0"
    }

    stages {
        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('Build and Push Docker Image') {
            steps {
                echo "Building and pushing Docker image: ${FULL_DOCKER_IMAGE} with Kaniko"
                container('kaniko') {
                    sh """
                        /kaniko/executor \
                          --dockerfile=Dockerfile \
                          --context=dir:///workspace \
                          --destination=${FULL_DOCKER_IMAGE} \
                          --cache=true \
                          --cache-dir=/cache
                    """
                }
            }
        }

        stage('Install Anchorectl CLI') {
            steps {
                echo "Installing anchorectl CLI version ${ANCHORECTL_VERSION}..."
                sh """
                    apk add --no-cache curl || true
                    curl -sSfL https://anchorectl-releases.anchore.io/anchorectl/install.sh | sh -s -- -b /usr/local/bin ${ANCHORECTL_VERSION}
                    anchorectl --version
                """
            }
        }

        stage('Scan with Anchore') {
            steps {
                echo "Scanning Docker image with Anchore: ${FULL_DOCKER_IMAGE}"
                script {
                    withCredentials([
                        string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORECTL_USERNAME'),
                        string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORECTL_PASSWORD')
                    ]) {
                        sh "anchorectl image add ${FULL_DOCKER_IMAGE}"
                        echo "Waiting for image analysis to complete in Anchore..."
                        sh "anchorectl image wait ${FULL_DOCKER_IMAGE}"
                        echo "Evaluating image against policy: ${ANCHORE_POLICY}"
                        def anchorePolicyCheckResult = sh(script: """
                            anchorectl image check --policy "${ANCHORE_POLICY}" ${FULL_DOCKER_IMAGE}
                        """, returnStatus: true)

                        if (anchorePolicyCheckResult != 0) {
                            error "Anchore policy evaluation failed for ${FULL_DOCKER_IMAGE}. Check logs for details."
                        } else {
                            echo "Anchore policy evaluation passed for ${FULL_DOCKER_IMAGE}."
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished for ${FULL_DOCKER_IMAGE}"
        }
    }
}
