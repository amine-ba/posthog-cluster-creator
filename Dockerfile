
# Use the offical golang image to create a binary.
# This is based on Debian and sets the GOPATH to /go.
# https://hub.docker.com/_/golang
FROM golang:1.19-buster as builder

# Create and change to the app directory.
WORKDIR /app

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Retrieve application dependencies.
# This allows the container build to reuse cached dependencies.
# Expecting to copy go.mod and if present go.sum.
COPY go.* ./
RUN go mod download

# Copy local code to the container image.
COPY invoke.go ./

# Build the binary.
RUN go build -mod=readonly -v -o server

# Use the official Debian slim image for a lean production container.
# https://hub.docker.com/_/debian
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM debian:buster-slim
RUN set -x && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install Doctl
RUN su root
RUN apt update -y
RUN apt install -y snapd
RUN snap install core

RUN snap install doctl
RUN snap connect doctl:kube-config
RUN snap connect doctl:ssh-keys :ssh-keys
RUN snap connect doctl:dot-docker

RUN doctl auth init --context auto-cluster
RUN doctl account get

# Create and change to the app directory.
WORKDIR /

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/server /app/server
COPY deploy.sh ./

# Run the web service on container startup.
CMD ["/app/server"]