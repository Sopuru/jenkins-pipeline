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
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/bin/sh", "-c"]
    args: ["sleep infinity"]
    volumeMounts:
    - name: workspace-volume
      mountPath: /home/jenkins/agent
  serviceAccountName: jenkins
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
          withCredentials([usernamePassword(credentialsId: 'dockerhub-pat', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
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

    // NEW STAGES FOR ANCHORE
    stage('Install Anchorectl CLI') {
      steps {
        container('jnlp') {
          echo "Installing anchorectl CLI version ${ANCHORECTL_VERSION}..."
          sh """
            curl -sSfL https://anchorectl-releases.anchore.io/anchorectl/install.sh | sh -s -- -b /home/jenkins/agent/bin ${ANCHORECTL_VERSION}
          """
        }
      }
    }
    
    stage('Scan with Anchore') {
      steps {
        container('jnlp') {
          echo "Scanning Docker image with Anchore: ${IMAGE}:${TAG}"
          withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORECTL_USERNAME'),
                           string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORECTL_PASSWORD')]) {
            sh """
              export PATH=\$PATH:/home/jenkins/agent/bin
              anchorectl image add ${IMAGE}:${TAG} --wait
              
              anchorectl image wait ${IMAGE}:${TAG}
              if anchorectl image check --policy "${ANCHORE_POLICY}" ${IMAGE}:${TAG}; then
                echo "Anchore policy evaluation passed."
              else
                echo "Anchore policy evaluation failed."
                exit 1
              fi
            """
          }
        }
      }
    }
  }
}
