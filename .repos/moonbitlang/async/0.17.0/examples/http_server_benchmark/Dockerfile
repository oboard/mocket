# HTTP Server Benchmark Docker Image
# Supports Moonbit, Node.js, and Go implementations
FROM ubuntu:24.04

# Set environment to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    build-essential \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install Go
RUN GO_VERSION="1.25.3" \
    && apt-get update && apt-get install -y -q ca-certificates \
    && wget -q --timeout=30 --tries=3 -O go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz \
    && /usr/local/go/bin/go version

# Add Go to PATH
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Moonbit
ENV HOME="/root"
RUN curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash

# Add Moonbit to PATH
ENV PATH="/root/.moon/bin:${PATH}"

# Install wrk benchmark tool
RUN git clone https://github.com/wg/wrk.git /tmp/wrk \
    && cd /tmp/wrk \
    && make \
    && cp wrk /usr/local/bin \
    && rm -rf /tmp/wrk

# Verify installations
RUN moon version --all && \
    node --version && \
    go version

# Create working directory
WORKDIR /app

# Copy benchmark files
COPY . .

# Build Go binary
RUN cd examples/http_server_benchmark && go build -o http_server_benchmark_go http_server_benchmark.go

# Build Moonbit project
RUN moon build -C examples

# Expose ports for different servers
EXPOSE 3001 3002 3003

# Default command: run benchmark
CMD ["/bin/bash", "/app/examples/http_server_benchmark/bench.sh"]