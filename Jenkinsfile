// Simple Jenkinsfile to pull a Docker image and inspect its details.

pipeline {
    // Define the agent where the pipeline will run.
    // 'any' means Jenkins will use any available agent that can run Docker commands.
    agent any

    // Environment variables for the pipeline
    environment {
        // The Docker image to pull and inspect.
        // Replace 'alpine:latest' with the image you want to work with (e.g., 'ubuntu:latest', 'nginx:stable').
        DOCKER_IMAGE_TO_PULL = "alpine:latest"
    }

    // Stages of the pipeline
    stages {
        // Stage 1: Checkout Source Code (still needed for the Jenkinsfile itself)
        stage('Checkout') {
            steps {
                echo "Checking out source code (Jenkinsfile)..."
                script {
                    checkout scm
                }
            }
        }

        // Stage 2: Install Docker CLI Prerequisites
        // This stage installs the Docker CLI client inside the Jenkins agent container.
        // It runs as the 'root' user within this specific step to handle apt permissions,
        // as the default 'jenkins' user often lacks necessary privileges.
        stage('Install Docker CLI Prerequisites') {
            agent {
                // IMPORTANT: This tells Jenkins to run this *specific* stage as the 'root' user (UID 0)
                // within the container. This is necessary for apt-get to have write permissions.
                // This assumes the container allows running as root, which `jenkins/jenkins:lts` does.
                docker {
                    image 'jenkins/jenkins:lts' // Use the same Jenkins base image
                    args '-u 0' // Run as root user (UID 0)
                    // Ensure the Docker socket is mounted to allow interaction with the host's Docker daemon
                    // This is crucial for 'docker' commands to work in subsequent stages.
                    args '-v /var/run/docker.sock:/var/run/docker.sock'
                    // Also keep the jenkins_home volume for persistence
                    args '-v jenkins_home:/var/jenkins_home'
                }
            }
            steps {
                echo "Installing Docker CLI tools in the Jenkins agent as root..."
                sh '''
                    # Clean up partial lists and ensure correct permissions for apt operations
                    # This helps if previous failed runs left apt in a bad state
                    rm -rf /var/lib/apt/lists/*
                    mkdir -p /var/lib/apt/lists/partial
                    chmod 755 /var/lib/apt/lists/partial

                    # Suppress apt-get output for cleaner logs
                    apt-get update -qq > /dev/null
                    
                    # Install prerequisites for adding Docker's official GPG key and repository
                    apt-get install -y --no-install-recommends \
                    apt-transport-https \
                    ca-certificates \
                    curl \
                    gnupg \
                    lsb-release

                    # Add Docker's official GPG key
                    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                    
                    # Add Docker's stable repository
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
                    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                    
                    # Update apt-get again to recognize the new Docker repository
                    apt-get update -qq > /dev/null
                    
                    # Install the Docker CLI client (docker-ce-cli)
                    apt-get install -y --no-install-recommends docker-ce-cli
                    
                    # Verify docker client is installed and accessible
                    docker --version
                '''
            }
        }

        // Stage 3: Pull Docker Image
        stage('Pull Docker Image') {
            steps {
                echo "Pulling Docker image: ${DOCKER_IMAGE_TO_PULL}..."
                script {
                    // Use the 'docker' DSL from the Docker Pipeline plugin to pull the image
                    docker.image("${DOCKER_IMAGE_TO_PULL}").pull()
                }
            }
        }

        // Stage 4: Inspect Docker Image
        stage('Inspect Docker Image') {
            steps {
                echo "Inspecting Docker image: ${DOCKER_IMAGE_TO_PULL}..."
                script {
                    // Execute 'docker inspect' command. The output will be printed to the console.
                    sh "docker inspect ${DOCKER_IMAGE_TO_PULL}"
                }
            }
        }
    }

    // Define post-build actions
    post {
        always {
            echo "Pipeline finished for Docker image: ${DOCKER_IMAGE_TO_PULL}"
        }
    }
}
