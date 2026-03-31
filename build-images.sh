#!/bin/bash
# build-images.sh
DOCKER_USER="tijnsemmekrot"
VERSION=$(date +%Y%m%d-%H%M)

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=("account-service" "fraud-detector" "notification-service" "payment-processor" "payment-requester")

for service in "${SERVICES[@]}"; do
  REPO_NAME="traces-test-$service"
  TAG="$VERSION"
  echo "--- Building $service with tag $TAG ---"

  # Use the absolute path relative to the script location
  docker build -t "$DOCKER_USER/$REPO_NAME:$TAG" "$SCRIPT_DIR/apps/$service"
  docker push "$DOCKER_USER/$REPO_NAME:$TAG"
done

echo "All images built and pushed successfully!"
