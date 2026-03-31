#!/bin/bash
# build-images.sh

ECR_ENDPOINT="localhost:4566"
ECR_REGISTRY="000000000000.dkr.ecr.eu-west-1.localhost.localstack.cloud:4566"
VERSION=$(date +%Y%m%d-%H%M)

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICES=("account-service" "fraud-detector" "notification-service" "payment-processor" "payment-requester")

echo "--- Logging in to LocalStack ECR ---"
# LocalStack ECR doesn't require real authentication, but we still need to login
aws ecr get-login-password --region eu-west-1 --endpoint-url=http://localhost:4566 |
  docker login --username AWS --password-stdin $ECR_REGISTRY

for service in "${SERVICES[@]}"; do
  REPO_NAME="traces-test-$service"
  TAG="$VERSION"
  FULL_IMAGE="$ECR_REGISTRY/$REPO_NAME:$TAG"

  echo "--- Building $service with tag $TAG ---"
  docker build -t "$FULL_IMAGE" "$SCRIPT_DIR/apps/$service"

  echo "--- Pushing $FULL_IMAGE ---"
  docker push "$FULL_IMAGE"
done

echo "All images built and pushed successfully to LocalStack ECR!"
