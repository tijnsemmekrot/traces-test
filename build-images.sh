#!/bin/bash
# build-images.sh
DOCKER_USER="tijnsemmekrot"
REPO_NAME="traces-test"
VERSION=$(date +%Y%m%d-%H%M)

SERVICES=("account-service" "fraud-detector" "notification-service" "payment-processor" "payment-requester")

for service in "${SERVICES[@]}"; do
  TAG="$service-$VERSION"
  echo "--- Building $service with tag $TAG ---"
  docker build -t "$DOCKER_USER/$REPO_NAME:$TAG" "./apps/$service"
  docker push "$DOCKER_USER/$REPO_NAME:$TAG"
done
