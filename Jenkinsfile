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
    # No volume mount needed for the secret here!
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
    IMAGE = "docker.io/your-dockerhub-username/your-image"
    TAG = "latest"
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
          // Use the withCredentials step to access the PAT
          withCredentials([usernamePassword(credentialsId: 'dockerhub-pat',
                                            usernameVariable: 'DOCKER_USER',
                                            passwordVariable: 'DOCKER_PASS')]) {
            sh """
              # Create the config.json file in the Kaniko container
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
  }
}
