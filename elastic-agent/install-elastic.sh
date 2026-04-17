#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# IMPORTANT: This MUST match the repoURL in your kargo-project.yaml exactly
REPO_URL="https://github.com/tijnsemmekrot/traces-test"

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

# 7. Deploy ArgoCD Applications
echo "🔄 Deploying ArgoCD applications..."
kubectl apply -f "$SCRIPT_DIR/argocd/dev-app.yaml"
kubectl apply -f "$SCRIPT_DIR/argocd/staging-app.yaml"
kubectl apply -f "$SCRIPT_DIR/argocd/prod-app.yaml"

echo ""
echo "========================================"
echo "✅ Installation Complete!"
echo "========================================"
echo ""
echo "Verifying git credentials setup:"
echo -n "Annotation: "
kubectl get secret git-credentials -n elastic-agent-kargo -o jsonpath='{.metadata.annotations.kargo\.akuity\.io/repo-url}'
echo ""
echo -n "Label: "
kubectl get secret git-credentials -n elastic-agent-kargo -o jsonpath='{.metadata.labels.kargo\.akuity\.io/cred-type}'
echo ""
echo ""
echo "If annotation shows: https://github.com/tijnsemmekrot/traces-test"
echo "Then you're ready to retry the promotion!"
