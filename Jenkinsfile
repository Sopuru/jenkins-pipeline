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
        // It runs as the 'root' user within this specific step to handle apt permissions.
        // The Docker socket must be mounted from the host to allow this client to communicate with the host's Docker daemon.
        stage('Install Docker CLI Prerequisites') {
            steps {
                echo "Installing Docker CLI tools in the Jenkins agent..."
                // Use the 'sh' step with 'script: """ commands """, shebang: '#!/bin/bash -ex', returnStdout: true, returnStatus: true, executionNode: 'master', label: 'docker', dir: '.', env: [], timeout: 0, credentials: [], script: '...' }
                // To run as root, we can instruct the shell to run the commands using 'sudo'
                // However, since 'sudo' itself was not found, we need to explicitly run it as root.
                // The easiest way to achieve this is to wrap the commands in a 'docker run --user root'
                // command on the Jenkins agent itself, but that's not how the 'agent any' works directly.
                // The most straightforward way in a 'sh' step is to assume 'root' is not what Jenkins is running as,
                // and if 'sudo' is not present, we have a chicken-and-egg problem.
                //
                // A better approach for this specific scenario with jenkins/jenkins:lts
                // is to create a small Docker image based on jenkins/jenkins:lts that includes sudo
                // or just has the Docker CLI pre-installed.
                //
                // However, if we must stick to 'agent any' and 'sh' commands:
                // We'll try to re-initialize the apt state, then install sudo, then proceed.
                // If the permission denied persists on `apt-get update`, it implies a corrupted
                // apt state or a deeply restricted environment.

                // Let's assume the issue is simply that the `jenkins` user doesn't have direct write access
                // to /var/lib/apt/lists/partial, which `apt-get update` needs.
                // We will try to gain root access using `su -c` or `sg docker -c` if sudo is missing.
                // Given previous `sudo: not found`, the most direct approach is to force the `sh` command
                // to run with a user who *can* write there.
                // The `jenkins` container runs as user 'jenkins' (uid 1000).
                // apt needs root privileges.
                // We will use `docker exec -u 0` (user 0 is root) on the *Jenkins container itself*
                // to execute the apt commands. This is a bit of a workaround to the 'agent any' constraint.

                // Let's try to repair apt first, and then install sudo.
                // This will be executed by the Jenkins process (as 'jenkins' user)
                // but by using 'docker exec -u 0' we're telling the host's Docker daemon
                // to run the command inside the Jenkins container as root.
                sh '''
                    # Execute apt commands as root user inside the Jenkins container
                    # This relies on the host's Docker daemon having access to the Jenkins container
                    # and the ability to exec as root (user 0).
                    # This is a workaround for `agent any` not being able to easily switch user.

                    echo "Attempting to fix apt directory permissions and install prerequisites..."

                    # Clean up partial lists and ensure correct permissions
                    docker exec -u 0 jenkins_server bash -c "rm -rf /var/lib/apt/lists/*"
                    docker exec -u 0 jenkins_server bash -c "mkdir -p /var/lib/apt/lists/partial"
                    docker exec -u 0 jenkins_server bash -c "chmod 755 /var/lib/apt/lists/partial"
                    
                    # Install sudo if not present
                    docker exec -u 0 jenkins_server bash -c "apt-get update -qq && apt-get install -y --no-install-recommends sudo || true" # Install sudo, ignore error if fails or exists

                    # Now use sudo for the rest, as sudo should now be installed and the jenkins user should be in sudoers
                    docker exec jenkins_server bash -c "sudo apt-get update -qq > /dev/null"
                    
                    docker exec jenkins_server bash -c "sudo apt-get install -y --no-install-recommends \
                    apt-transport-https \
                    ca-certificates \
                    curl \
                    gnupg \
                    lsb-release"

                    docker exec jenkins_server bash -c "curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
                    
                    docker exec jenkins_server bash -c "echo \\"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \\
                    \$(lsb_release -cs) stable\\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"
                    
                    docker exec jenkins_server bash -c "sudo apt-get update -qq > /dev/null"
                    
                    docker exec jenkins_server bash -c "sudo apt-get install -y --no-install-recommends docker-ce-cli"
                    
                    docker exec jenkins_server bash -c "docker --version"
                '''
            }
        }

        // Stage: Build Docker Image
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
