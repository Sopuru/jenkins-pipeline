// Jenkinsfile for Docker Image Build and Anchore Scanning
// This is a declarative pipeline that automates building, tagging,
// pushing (optional), and scanning a Docker image with Anchore.

pipeline {
    // Define the agent where the pipeline will run.
    // 'any' means Jenkins will use any available agent.
    // For Docker builds, ensure the agent has Docker installed.
    agent any

    // Environment variables for the pipeline
    environment {
        // Docker image name and tag
        DOCKER_IMAGE_NAME = "joshua" // Using the image name from your logs
        DOCKER_IMAGE_TAG = "latest"
        // Full Docker image name including registry (if pushing)
        FULL_DOCKER_IMAGE = "sopuru24/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" // Using your Docker Hub username from logs

        // Anchore API endpoint (ANCHORE_ENGINE_URL is the standard variable name used by Anchore CLI to point to the core service)
        ANCHORE_ENGINE_URL = "http://anchore_host:8228/v1" // Replace with your Anchore host/IP
        // Anchore Analyzer URL (internal URL for Jenkins agent to reach Anchore's Analyzer service)
        // This is often the same as ANCHORE_ENGINE_URL if running locally or accessible.
        ANCHORE_ANALYZER_URL = "http://anchore_host:8228/v1" // Replace if different
        // Policy to evaluate against (optional, 'default' is common)
        ANCHORE_POLICY = "default"
    }

    // Stages of the pipeline
    stages {
        // Stage 1: Checkout Source Code
        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                script {
                    checkout scm
                }
            }
        }

        // Stage: Install Docker CLI Prerequisites
        // This stage installs the Docker CLI client inside the Jenkins agent container.
        // We explicitly run this stage as the 'root' user to handle apt permissions,
        // as the default 'jenkins' user often lacks necessary privileges.
        stage('Install Docker CLI Prerequisites') {
            agent {
                // IMPORTANT: This tells Jenkins to run this *specific* stage as the 'root' user (UID 0)
                // within the container. This is necessary for apt-get to have write permissions.
                // This assumes the container allows running as root, which `jenkins/jenkins:lts` does.
                docker {
                    image 'jenkins/jenkins:lts' // Use the same image, but override user
                    args '-u 0' // Run as root user (UID 0)
                    // Ensure the Docker socket is mounted even when explicitly specifying the image
                    args '-v /var/run/docker.sock:/var/run/docker.sock -v jenkins_home:/var/jenkins_home'
                }
            }
            steps {
                echo "Installing Docker CLI tools in the Jenkins agent as root..."
                sh '''
                    # Clean up partial lists and ensure correct permissions for apt operations
                    # This is done first because previous runs might have left it in a bad state
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

        // Stage: Build Docker Image
        // This stage will now run with 'agent any', meaning it will default back to the 'jenkins' user
        // However, since the previous stage installed docker-ce-cli, the 'docker' command should be available
        // to the 'jenkins' user if they have the right group permissions (usually handled by docker-ce-cli installation).
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${FULL_DOCKER_IMAGE}"
                script {
                    docker.build "${FULL_DOCKER_IMAGE}", "--pull ."
                }
            }
        }

        // Stage: Push Docker Image to Registry (Optional)
        /*
        stage('Push Docker Image') {
            steps {
                echo "Pushing Docker image: ${FULL_DOCKER_IMAGE} to Docker Hub..."
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'DOCKER_REGISTRY_CREDENTIALS') {
                        docker.image("${FULL_DOCKER_IMAGE}").push()
                    }
                }
            }
        }
        */

        // Stage: Scan with Anchore
        stage('Scan with Anchore') {
            steps {
                echo "Scanning Docker image with Anchore: ${FULL_DOCKER_IMAGE}"
                script {
                    withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORE_CLI_USER'),
                                     string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORE_CLI_PASS')]) {
                        sh """
                            docker run --rm \
                                -e ANCHORE_CLI_USER=${ANCHORE_CLI_USER} \
                                -e ANCHORE_CLI_PASS=${ANCHORE_CLI_PASS} \
                                -e ANCHORE_CLI_URL=${ANCHORE_ENGINE_URL} \
                                -e ANCHORE_ENGINE_URL=${ANCHORE_ENGINE_URL} \
                                -e ANCHORE_CLI_ANALYZER_URL=${ANCHORE_ANALYZER_URL} \
                                anchore/cli:latest \
                                image add ${FULL_DOCKER_IMAGE}
                        """

                        echo "Waiting for image analysis to complete in Anchore..."
                        sh """
                            docker run --rm \
                                -e ANCHORE_CLI_USER=${ANCHORE_CLI_USER} \
                                -e ANCHORE_CLI_PASS=${ANCHORE_CLI_PASS} \
                                -e ANCHORE_CLI_URL=${ANCHORE_ENGINE_URL} \
                                anchore/cli:latest \
                                image wait ${FULL_DOCKER_IMAGE}
                        """

                        echo "Evaluating image against policy: ${ANCHORE_POLICY}"
                        def anchorePolicyCheckResult = sh(script: """
                            docker run --rm \
                                -e ANCHORE_CLI_USER=${ANCHORE_CLI_USER} \
                                -e ANCHORE_CLI_PASS=${ANCHORE_CLI_PASS} \
                                -e ANCHORE_CLI_URL=${ANCHORE_ENGINE_URL} \
                                anchore/cli:latest \
                                image check --policy ${ANCHORE_POLICY} ${FULL_DOCKER_IMAGE}
                        """, returnStatus: true)

                        if (anchorePolicyCheckResult != 0) {
                            error "Anchore policy evaluation failed for ${FULL_DOCKER_IMAGE}. Check logs for details."
                        } else {
                            echo "Anchore policy evaluation passed for ${FULL_DOCKER_IMAGE}."
                        }

                        echo "Generating SBOM for ${FULL_DOCKER_IMAGE}"
                        sh """
                            docker run --rm \
                                -e ANCHORE_CLI_USER=${ANCHORE_CLI_USER} \
                                -e ANCHORE_CLI_PASS=${ANCHORE_CLI_PASS} \
                                -e ANCHORE_CLI_URL=${ANCHORE_ENGINE_URL} \
                                anchore/cli:latest \
                                image sbom ${FULL_DOCKER_IMAGE} spdx > ${DOCKER_IMAGE_NAME}-${DOCKER_IMAGE_TAG}-sbom.spdx.json
                        """
                        archiveArtifacts artifacts: "${DOCKER_IMAGE_NAME}-${DOCKER_IMAGE_TAG}-sbom.spdx.json", fingerprint: true
                    }
                }
            }
        }
    }

    // Define post-build actions, e.g., clean up, send notifications
    post {
        always {
            echo "Pipeline finished for ${FULL_DOCKER_IMAGE}"
        }
        // Add a clean-up step if you want to remove the local Docker image after scan
        // This is useful to free up disk space on the Jenkins agent.
        // Note: This will not remove the image from Anchore, only from the local Docker daemon.
        /*
        cleanup {
            script {
                echo "Cleaning up local Docker image: ${FULL_DOCKER_IMAGE}"
                try {
                    docker.image("${FULL_DOCKER_IMAGE}").remove()
                } catch (err) {
                    echo "Failed to remove image: ${err}"
                }
            }
        }
        */
    }
}
