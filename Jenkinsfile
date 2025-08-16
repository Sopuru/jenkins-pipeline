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
      steps { // <<-- Missing steps block
        // Run this step in the default 'jnlp' agent container
        container('jnlp') {
          steps {
            echo "Installing anchorectl CLI version ${ANCHORECTL_VERSION}..."
            sh """
              # Use curl to get the installation script and install to a user-writable location
              curl -sSfL https://anchorectl-releases.anchore.io/anchorectl/install.sh | sh -s -- -b /home/jenkins/agent/bin ${ANCHORECTL_VERSION}
            """
          }
        }
      } // <<-- Missing steps block
    }
    
    stage('Scan with Anchore') {
      steps { // <<-- Missing steps block
        // Run this step in the default 'jnlp' agent container
        container('jnlp') {
          steps {
            echo "Scanning Docker image with Anchore: ${IMAGE}:${TAG}"
            withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORECTL_USERNAME'),
                             string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORECTL_PASSWORD')]) {
              sh """
                # Add the newly installed anchorectl to the PATH
                export PATH=\$PATH:/home/jenkins/agent/bin
                # Add the Docker image to Anchore for analysis
                anchorectl image add ${IMAGE}:${TAG}
                # Wait for the image analysis to complete in Anchore
                anchorectl image wait ${IMAGE}:${TAG}
                # Evaluate the image against a policy
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
      } // <<-- Missing steps block
    }
  }
}
