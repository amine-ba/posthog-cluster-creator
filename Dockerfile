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

# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM ubuntu:latest
FROM docker:latest
FROM henry40408/doctl-kubectl:latest

ARG DO_TOKEN=dop_v1_3181778d458989a35181e6a4d057333a1786c0ab546581117ba0b2240505d970
RUN docker run --rm -it sh \
  --env=DIGITALOCEAN_ACCESS_TOKEN=DO_TOKEN \
  doctl account get

# Create and change to the app directory.
WORKDIR /

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/server /app/server
COPY deploy.sh ./

# Run the web service on container startup.
CMD ["/app/server"]