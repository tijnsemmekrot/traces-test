#!/usr/bin/env bash
set -e

# Configuration
ELASTIC_VERSION="${1:-9.3.0}"
# Use the LocalStack registry URL for the tag
ECR_REGISTRY="000000000000.dkr.ecr.eu-west-1.localhost.localstack.cloud:4566"
ECR_REPO="${ECR_REGISTRY}/elastic-agent"
AWS_REGION="eu-west-1"
ENDPOINT_URL="http://localhost:4566"

echo "========================================"
echo "Building and Syncing Patched Elastic Agent to LocalStack ECR"
echo "========================================"

# 1. Build the local Dockerfile (this applies your apk upgrades)
echo "🛠️  Building patched image..."
docker build --build-arg IMAGEVERSION=${ELASTIC_VERSION} -t "${ECR_REPO}:${ELASTIC_VERSION}" .
docker tag "${ECR_REPO}:${ELASTIC_VERSION}" "${ECR_REPO}:latest"

# 2. Login to LocalStack ECR
echo "🔐 Logging into LocalStack ECR..."
aws ecr get-login-password --region ${AWS_REGION} --endpoint-url=${ENDPOINT_URL} |
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# 3. Push to LocalStack
echo "📤 Pushing to LocalStack..."
docker push "${ECR_REPO}:${ELASTIC_VERSION}"
docker push "${ECR_REPO}:latest"

echo ""
echo "✅ Successfully synced patched elastic-agent:${ELASTIC_VERSION} to LocalStack"
