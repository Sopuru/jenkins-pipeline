// Jenkinsfile for Docker Image Build and Anchore Scanning
// This is a declarative pipeline that automates building, tagging,
// pushing (optional), and scanning a Docker image with Anchore.

pipeline {
    // Define the agent where the pipeline will run.
    // 'any' means Jenkins will use any available agent that can run Docker commands.
    // This pipeline assumes the Jenkins master itself is running in a Docker container
    // that has the Docker CLI installed and has the host's Docker socket mounted.
    agent any

    // Environment variables for the pipeline
    environment {
        // Docker image name and tag
        DOCKER_IMAGE_NAME = "joshua" // Example image name
        DOCKER_IMAGE_TAG = "latest"
        // Full Docker image name including registry (if pushing)
        FULL_DOCKER_IMAGE = "sopuru24/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" // Example Docker Hub username/image

        // Anchore API endpoint (ANCHORE_CLI_URL is used by anchorectl to connect to the Anchore service)
        ANCHORE_CLI_URL = "https://anchore.nizati.com/" // Replace with your Anchore host/IP
        // Policy to evaluate against (optional, 'default' is common)
        ANCHORE_POLICY = "Anchore Enterprise - Secure v20250101"
        // anchorectl version to install
        ANCHORECTL_VERSION = "v5.18.0"
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

        // Stage 2: Build Docker Image
        stage('Build Docker Image') {
            steps {
                echo "Building Docker image: ${FULL_DOCKER_IMAGE}"
                script {
                    // Use the 'docker' DSL provided by Docker Pipeline plugin
                    // This works because the Jenkins master container (my-jenkins-docker-with-cli)
                    // has the Docker CLI installed and the Docker socket mounted.
                    docker.build "${FULL_DOCKER_IMAGE}", "--pull ."
                }
            }
        }

        // Stage 3: Push Docker Image to Registry (Optional)
        // Uncomment this stage if you need to push the image to a registry
        // (e.g., Docker Hub, private registry) before scanning.
        /*
        stage('Push Docker Image') {
            steps {
                echo "Pushing Docker image: ${FULL_DOCKER_IMAGE} to Docker Hub..."
                script {
                    // Use 'withRegistry' to authenticate with the Docker registry
                    // The 'DOCKER_REGISTRY_CREDENTIALS' ID must match the one configured in Jenkins Credentials.
                    docker.withRegistry('https://index.docker.io/v1/', 'DOCKER_REGISTRY_CREDENTIALS') {
                        docker.image("${FULL_DOCKER_IMAGE}").push()
                    }
                }
            }
        }
        */

        // NEW STAGE: Install Anchorectl CLI
        // This stage downloads and installs the anchorectl CLI tool in the Jenkins agent.
        // It uses the recommended installation script provided by Anchore.
        stage('Install Anchorectl CLI') {
            steps {
                echo "Installing anchorectl CLI version ${ANCHORECTL_VERSION}..."
                sh """
                    # Download and execute the anchorectl installation script
                    # The script handles extraction and placing the binary in /usr/local/bin
                    # Using sudo as /usr/local/bin often requires root privileges
                    curl -sSfL https://anchorectl-releases.anchore.io/anchorectl/install.sh | sudo sh -s -- -b /usr/local/bin ${ANCHORECTL_VERSION}
                    
                    # Verify anchorectl is installed and accessible
                    anchorectl --version
                """
            }
        }

        // Stage 5: Scan Docker Image with Anchore (using anchorectl)
        stage('Scan with Anchore') {
            steps {
                echo "Scanning Docker image with Anchore: ${FULL_DOCKER_IMAGE}"
                script {
                    // Bind Anchore credentials from Jenkins to environment variables
                    // These variables (ANCHORE_CLI_USER, ANCHORE_CLI_PASS) are picked up by anchorectl
                    withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORE_CLI_USER'),
                                     string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORE_CLI_PASS')]) {
                        // Add the Docker image to Anchore for analysis
                        // anchorectl uses ANCHORE_CLI_URL from the environment for connection
                        sh "anchorectl image add ${FULL_DOCKER_IMAGE}"

                        // Wait for the image analysis to complete in Anchore
                        echo "Waiting for image analysis to complete in Anchore..."
                        sh "anchorectl image wait ${FULL_DOCKER_IMAGE}"

                        // Evaluate the image against a policy
                        echo "Evaluating image against policy: ${ANCHORE_POLICY}"
                        def anchorePolicyCheckResult = sh(script: """
                            anchorectl image check ${FULL_DOCKER_IMAGE}
                        """, returnStatus: true) // Return the exit status

                        // Check the exit status of the Anchore policy evaluation
                        // A non-zero exit status usually indicates a policy violation.
                        if (anchorePolicyCheckResult = 0) {
                            error "Anchore policy evaluation failed for ${FULL_DOCKER_IMAGE}. Check logs for details."
                        } else {
                            echo "Anchore policy evaluation passed for ${FULL_DOCKER_IMAGE}."
                        }

                        // Optional: Generate an SBOM (Software Bill of Materials) report
                        echo "Generating SBOM for ${FULL_DOCKER_IMAGE}"
                        
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
