DOCKER_USER="tijnsemmekrot"
REPO_NAME="traces-test"

for service in account-service fraud-detector notification-service payment-processor payment-requester; do
  echo "Building and Pushing $service..."
  # Build and tag: tijnsemmekrot/traces-test:account-service
  docker build -t "$DOCKER_USER/$REPO_NAME:$service" "./apps/$service"
  docker push "$DOCKER_USER/$REPO_NAME:$service"
done
