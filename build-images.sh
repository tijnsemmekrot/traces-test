#!/bin/bash
set -e # Exit on any error

# build-images.sh
ECR_ENDPOINT="localhost:4566"
ECR_REGISTRY="000000000000.dkr.ecr.eu-west-1.localhost.localstack.cloud:4566"
VERSION=$(date +%Y%m%d-%H%M)

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=("account-service" "fraud-detector" "notification-service" "payment-processor" "payment-requester")

echo "--- Logging in to LocalStack ECR ---"
aws ecr get-login-password --region eu-west-1 --endpoint-url=http://localhost:4566 |
  docker login --username AWS --password-stdin $ECR_REGISTRY

for service in "${SERVICES[@]}"; do
  REPO_NAME="traces-test-$service"

  # Define both tags
  VERSION_IMAGE="$ECR_REGISTRY/$REPO_NAME:$VERSION"
  LATEST_IMAGE="$ECR_REGISTRY/$REPO_NAME:latest"

  echo "--- Building $service ---"
  # Build once, tag twice
  docker build -t "$VERSION_IMAGE" -t "$LATEST_IMAGE" "$SCRIPT_DIR/apps/$service"

  echo "--- Pushing $service (tags: $VERSION and latest) ---"
  docker push "$VERSION_IMAGE"
  docker push "$LATEST_IMAGE"
done

echo "------------------------------------------------------------"
echo "All images built and pushed successfully to LocalStack ECR!"
echo "Your manifests should now point to the :latest tag."
