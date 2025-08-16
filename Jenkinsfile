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
    image: gcr.io/kaniko-project/executor:latest
    command:
    - cat
    tty: true
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
            /kaniko/executor \
              --dockerfile=Dockerfile \
              --context=${WORKSPACE} \
              --destination=${IMAGE}:${TAG} \
              --cleanup
          """
        }
      }
    }

    stage('Anchore Scan') {
      steps {
        anchore name: 'anchore_scan', image: "${IMAGE}:${TAG}", policy: ''
      }
    }
  }
}
