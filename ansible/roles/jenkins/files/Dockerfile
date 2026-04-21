FROM jenkins/jenkins:lts

USER root

# ============================================
# OS tools (clean & stable)
# ============================================
RUN apt-get update && apt-get install -y \
    docker.io \
    git \
    curl \
    unzip \
    sshpass \
    ansible \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY plugins.txt /plugins.txt

RUN jenkins-plugin-cli --plugin-file /plugins.txt

USER jenkins