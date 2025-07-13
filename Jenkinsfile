// Jenkinsfile for Docker Image Build and Anchore Scanning
// This is a declarative pipeline that automates building, tagging,
// pushing (optional), and scanning a Docker image with Anchore.

pipeline {
    // Define the agent where the pipeline will run.
    // 'kaniko-builder' label corresponds to the podTemplate defined in Helm values.
    agent { label 'kaniko-builder' }

    // Environment variables for the pipeline
    environment {
        // Docker image name and tag
        DOCKER_IMAGE_NAME = "joshua" // Example image name
        DOCKER_IMAGE_TAG = "${env.BUILD_NUMBER}" // Use Jenkins build number for unique tags
        // Full Docker image name including registry (if pushing)
        FULL_DOCKER_IMAGE = "sopuru24/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}" // Example Docker Hub username/image

        // Anchore API endpoint - using newer ANCHORECTL_URL for anchorectl
        ANCHORECTL_URL = "https://anchore.nizati.com/"

        // Policy to evaluate against (optional, 'default' is common)
        ANCHORE_POLICY = "Anchore Enterprise - Secure v20250101"
        // anchorectl version to install
        ANCHORECTL_VERSION = "v5.18.0" // User's specified version
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

        // Stage 2: Build and Push Docker Image using Kaniko
        stage('Build and Push Docker Image') {
            steps {
                echo "Building and pushing Docker image: ${FULL_DOCKER_IMAGE} with Kaniko"
                // Run the Kaniko command inside the 'kaniko' sidecar container
                container('kaniko') {
                    sh """
                        /kaniko/executor \\
                          --dockerfile=Dockerfile \\
                          --context=dir:///workspace \\
                          --destination=${FULL_DOCKER_IMAGE} \\
                          --cache=true \\
                          --cache-dir=/cache
                    """
                    // Kaniko automatically pushes to the destination if --no-push is not set or is false.
                    // The mounted 'docker-config' secret handles authentication.
                }
            }
        }

        // NEW STAGE: Install Anchorectl CLI
        // This stage downloads and installs the anchorectl CLI tool in the Jenkins agent.
        // It uses the recommended installation script provided by Anchore.
        stage('Install Anchorectl CLI') {
            steps {
                echo "Installing anchorectl CLI version ${ANCHORECTL_VERSION}..."
                // Ensure 'curl' is available in the jnlp container. If not, you might need
                // to add 'apk add curl' for alpine-based or 'apt-get update && apt-get install -y curl' for debian-based
                // agent images, or build a custom agent image.
                sh """
                    # Install curl if not present (assuming alpine-based 'jenkins/inbound-agent')
                    apk add --no-cache curl || true

                    # Download and execute the anchorectl installation script
                    curl -sSfL https://anchorectl-releases.anchore.io/anchorectl/install.sh | sh -s -- -b /usr/local/bin ${ANCHORECTL_VERSION}
                    
                    # Verify anchorectl is installed and accessible
                    anchorectl --version
                """
            }
        }

        // Stage 4: Scan Docker Image with Anchore (using anchorectl)
        stage('Scan with Anchore') {
            steps {
                echo "Scanning Docker image with Anchore: ${FULL_DOCKER_IMAGE}"
                script {
                    // Bind Anchore credentials from Jenkins to environment variables
                    withCredentials([string(credentialsId: 'ANCHORE_USER', variable: 'ANCHORECTL_USERNAME'),
                                     string(credentialsId: 'ANCHORE_PASS', variable: 'ANCHORECTL_PASSWORD')]) {
                        // Add the Docker image to Anchore for analysis
                        sh "anchorectl image add ${FULL_DOCKER_IMAGE}"

                        // Wait for the image analysis to complete in Anchore
                        echo "Waiting for image analysis to complete in Anchore..."
                        sh "anchorectl image wait ${FULL_DOCKER_IMAGE}"

                        // Evaluate the image against a policy
                        echo "Evaluating image against policy: ${ANCHORE_POLICY}"
                        def anchorePolicyCheckResult = sh(script: """
                            anchorectl image check --policy "${ANCHORE_POLICY}" ${FULL_DOCKER_IMAGE}
                        """, returnStatus: true)

                        if (anchorePolicyCheckResult != 0) {
                            error "Anchore policy evaluation failed for ${FULL_DOCKER_IMAGE}. Check logs for details."
                        } else {
                            echo "Anchore policy evaluation passed for ${FULL_DOCKER_IMAGE}."
                        }
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
        // No local Docker image cleanup needed as Kaniko pushes directly.
    }
}
