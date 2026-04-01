#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# IMPORTANT: This MUST match the repoURL in your kargo-project.yaml exactly
REPO_URL="https://github.com/tijnsemmekrot/traces-test.git"

echo "========================================"
echo "Installing Elastic Agent with Kargo"
echo "========================================"

# 1. Create namespaces
echo "📦 Creating namespaces..."
kubectl apply -f "$SCRIPT_DIR/namespaces.yaml"

# 2. Create ECR credentials secret for each environment
echo "🔑 Creating ECR credentials for image pull..."
for ENV in dev staging prod; do
  kubectl create secret docker-registry ecr-credentials \
    --docker-server=000000000000.dkr.ecr.eu-west-1.localhost.localstack.cloud:4566 \
    --docker-username=AWS \
    --docker-password=000000000000-auth-token \
    --namespace=elastic-agent-${ENV} \
    --dry-run=client -o yaml | kubectl apply -f -
done

# 3. Setup Kargo project
echo "🚀 Setting up Kargo project..."
kubectl apply -f "$SCRIPT_DIR/argocd/kargo-project.yaml"

# --- FIX START ---
REPO_URL_FOR_KARGO="https://github.com/tijnsemmekrot/traces-test"

echo "🔑 Re-aligning Git credentials..."
kubectl delete secret git-credentials -n elastic-agent-kargo --ignore-not-found

kubectl create secret generic git-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=tijnsemmekrot \
  --from-literal=password=${GITHUB_TOKEN} \
  --type=kubernetes.io/basic-auth

# This annotation is what allows Kargo to find this secret during step-4
kubectl annotate secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/repo-url="${REPO_URL_FOR_KARGO}" \
  --overwrite

kubectl label secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/cred-type=git \
  --overwrite
# --- FIX END ---

# Create ECR credentials for Kargo Warehouse
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
