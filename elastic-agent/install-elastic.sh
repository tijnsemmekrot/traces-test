#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/tijnsemmekrot/localstack-test.git" # Update with your repo

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
    --docker-server=000000000000.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=000000000000-auth-token \
    --namespace=elastic-agent-${ENV} \
    --dry-run=client -o yaml | kubectl apply -f -
done

# 3. Setup Kargo project and git credentials
echo "🚀 Setting up Kargo project..."
kubectl apply -f "$SCRIPT_DIR/argocd/kargo-project.yaml"

# Create git credentials for Kargo
kubectl create secret generic git-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=tijnsemmekrot \
  --from-literal=password=${GITHUB_TOKEN} \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/secret-type=git \
  --overwrite

# Create ECR credentials for Kargo
kubectl create secret generic ecr-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=AWS \
  --from-literal=password=000000000000-auth-token \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret ecr-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/secret-type=registry \
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
echo ""
echo "📊 Next Steps:"
echo ""
echo "1. Sync elastic-agent image to ECR:"
echo "   ./scripts/sync-elastic-image.sh 8.12.0"
echo ""
echo "2. Check ArgoCD applications:"
echo "   kubectl get applications -n argocd | grep elastic-agent"
echo ""
echo "3. Monitor Kargo stages:"
echo "   kubectl get stages -n elastic-agent-kargo"
echo ""
echo "4. Access Kargo UI:"
echo "   kubectl port-forward -n kargo svc/kargo-api 8081:443"
echo "   Open: https://localhost:8081"
echo ""
echo "5. Promote to staging/prod:"
echo "   Use Kargo UI to manually promote from dev → staging → prod"
echo ""
echo "📍 Check deployment status:"
echo "   kubectl get daemonsets -n elastic-agent-dev"
echo "   kubectl get daemonsets -n elastic-agent-staging"
echo "   kubectl get daemonsets -n elastic-agent-prod"
