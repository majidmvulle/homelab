ARG RUNNER_VERSION=2.338.0
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

USER root

# Install essential build tools, make, container utilities, and commonly needed packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    make \
    curl \
    wget \
    git \
    jq \
    unzip \
    tar \
    gzip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

USER runner
