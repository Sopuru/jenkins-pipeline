pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: kaniko
spec:
  serviceAccountName: jenkins
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/bin/sh", "-c"]
    args: ["sleep infinity"]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  volumes:
  - name: workspace-volume
    emptyDir: {}
"""
    }
  }
  environment {
    IMAGE = "docker.io/sopuru24/joshua"
    TAG = "jenkinsP"

    // Anchore variables
    ANCHORECTL_URL = "https://anchore.nizati.com/"
    ANCHORE_POLICY = "Anchore Enterprise - Secure v20250101"
    ANCHORECTL_VERSION = "v5.20.0"
  }
  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/Sopuru/jenkins-pipeline.git'
      }
    }

    stage('Build and Push with Kaniko') {
      steps {
        container('kaniko') {
          withCredentials([usernamePassword(credentialsId: 'dockerhub-pat',
                                            usernameVariable: 'DOCKER_USER',
                                            passwordVariable: 'DOCKER_PASS')]) {
            sh """
              mkdir -p /kaniko/.docker
              echo "{\\"auths\\":{\\"https://index.docker.io/v1/\\":{\\"username\\":\\"\$DOCKER_USER\\",\\"password\\":\\"\$DOCKER_PASS\\"}}}" > /kaniko/.docker/config.json

              /kaniko/executor \\
                --dockerfile=Dockerfile \\
                --context=${WORKSPACE} \\
                --destination=${IMAGE}:${TAG} \\
                --cleanup
            """
          }
        }
      }
    }

    // New stages for Anchore scan
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
        echo "Scanning Docker image with Anchore: ${IMAGE}:${TAG}"
        script {
          withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORECTL_USERNAME'),
                           string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORECTL_PASSWORD')]) {
            sh "anchorectl image add ${IMAGE}:${TAG}"

            echo "Waiting for image analysis to complete in Anchore..."
            sh "anchorectl image wait ${IMAGE}:${TAG}"

            echo "Evaluating image against policy: ${ANCHORE_POLICY}"
            def anchorePolicyCheckResult = sh(script: """
              anchorectl image check --policy "${ANCHORE_POLICY}" ${IMAGE}:${TAG}
            """, returnStatus: true)

            if (anchorePolicyCheckResult != 0) {
              error "Anchore policy evaluation failed for ${IMAGE}:${TAG}. Check logs for details."
            } else {
              echo "Anchore policy evaluation passed for ${IMAGE}:${TAG}."
            }
          }
        }
      }
    }
  }
}
