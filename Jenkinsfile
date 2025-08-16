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
    # Use the debug version of the image which has a shell
    image: gcr.io/kaniko-project/executor:debug
    # Keep the container running indefinitely
    command: ["/bin/sh", "-c"]
    args: ["sleep infinity"]
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  volumes:
  - name: docker-config
    secret:
      secretName: dockerhub-secret
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
          sh """
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
