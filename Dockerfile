# Dockerfile to build a Jenkins image with Docker CLI installed
# Based on the official Jenkins LTS image

FROM jenkins/jenkins:lts

USER root

# Install Docker CLI prerequisites and Docker CLI itself
# These commands are run during the image build process
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends docker-ce-cli && \
    # Clean up apt cache to keep image size down
    rm -rf /var/lib/apt/lists/*

# Add the 'jenkins' user to the 'docker' group
# This is crucial so that the 'jenkins' user can interact with the Docker socket
RUN groupadd -r docker || true && usermod -aG docker jenkins

USER jenkins

# The Jenkins entrypoint is handled by the base image
