#!/bin/bash

set -e

# Check if kind is installed
if ! command -v kind &>/dev/null; then
  echo "kind is not installed. Installing kind..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  echo "kind installed successfully"
else
  echo "kind is already installed"
fi

# Check if kubectl is installed
if ! command -v kubectl &>/dev/null; then
  echo "kubectl is not installed. Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
  echo "kubectl installed successfully"
else
  echo "kubectl is already installed"
fi

# Check if docker is running
if ! docker info &>/dev/null; then
  echo "Docker is not running. Please start Docker and try again."
  exit 1
else
  echo "Docker is running"
fi

echo ""
echo "1. Creating kind cluster..."
kind create cluster --config kind-config.yaml

echo ""
echo "2. Building Docker images..."
echo "   Building payment-requester..."
docker build -t payment-requester:latest ./payment-requester

echo "   Building payment-processor..."
docker build -t payment-processor:latest ./payment-processor

echo "   Building fraud-detector..."
docker build -t fraud-detector:latest ./fraud-detector

echo "   Building account-service..."
docker build -t account-service:latest ./account-service

echo "   Building notification-service..."
docker build -t notification-service:latest ./notification-service

echo ""
echo "3. Loading images into kind cluster..."
kind load docker-image payment-requester:latest --name payment-cluster
kind load docker-image payment-processor:latest --name payment-cluster
kind load docker-image fraud-detector:latest --name payment-cluster
kind load docker-image account-service:latest --name payment-cluster
kind load docker-image notification-service:latest --name payment-cluster

echo ""
echo "4. Deploying applications to Kubernetes..."
kubectl apply -f payment-requester.yaml
kubectl apply -f payment-processor.yaml
kubectl apply -f fraud-detector.yaml
kubectl apply -f account-service.yaml
kubectl apply -f notification-service.yaml

helm install jaeger jaegertracing/jaeger

kubectl wait --for=condition=available deploy/jaeger --timeout=60s
kubectl port-forward svc/jaeger 16686:16686 &

echo "To delete the cluster:"
echo "  kind delete cluster --name payment-cluster"
echo ""
