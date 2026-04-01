#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/tijnsemmekrot/traces-test.git"

echo "========================================"
echo "Installing Elastic Agent with Kargo"
echo "========================================"

# 1. Create namespaces
echo "📦 Creating namespaces..."
kubectl apply -f "$SCRIPT_DIR/namespaces.yaml"

# 2. Create ECR credentials secret for each environment (for Kube pull secrets)
echo "🔑 Creating ECR credentials for image pull..."
for ENV in dev staging prod; do
  kubectl create secret docker-registry ecr-credentials \
    --docker-server=000000000000.dkr.ecr.eu-west-1.localhost.localstack.cloud:4566 \
    --docker-username=AWS \
    --docker-password=000000000000-auth-token \
    --namespace=elastic-agent-${ENV} \
    --dry-run=client -o yaml | kubectl apply -f -
done

# 3. Setup Kargo project and credentials
echo "🚀 Setting up Kargo project..."
kubectl apply -f "$SCRIPT_DIR/argocd/kargo-project.yaml"

# Create Git credentials for Kargo (CRITICAL: cred-type label)
echo "🔑 Creating Git credentials for Kargo push..."
kubectl create secret generic git-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=tijnsemmekrot \
  --from-literal=password=${GITHUB_TOKEN} \
  --type=kubernetes.io/basic-auth \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/cred-type=git \
  --overwrite

# Create ECR credentials for Kargo Warehouse (CRITICAL: cred-type label)
echo "🔑 Creating ECR credentials for Kargo Warehouse..."
kubectl create secret generic ecr-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=AWS \
  --from-literal=password=000000000000-auth-token \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret ecr-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/cred-type=image \
  --overwrite

# Grant Kargo access to secrets
kubectl create rolebinding kargo-controller-secret-reader \
  --clusterrole=kargo-project-secrets-reader \
  --serviceaccount=kargo:kargo-controller-manager \
  --namespace elastic-agent-kargo \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Deploy ArgoCD Applications
echo "🔄 Deploying ArgoCD applications..."
kubectl apply -f "$SCRIPT_DIR/argocd/dev-app.yaml"
kubectl apply -f "$SCRIPT_DIR/argocd/staging-app.yaml"
kubectl apply -f "$SCRIPT_DIR/argocd/prod-app.yaml"

echo ""
echo "========================================"
echo "✅ Installation Complete!"
echo "========================================"
