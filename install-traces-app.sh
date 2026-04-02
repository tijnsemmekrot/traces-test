#!/bin/bash

set -e

echo "Installing Kargo"
pass=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)
echo "Your Admin Password is: $pass"

# 2. Hash it (This requires 'apache2-utils' for the htpasswd command)
# If htpasswd is missing, use: pip install passlib and a python script
hashed_pass=$(htpasswd -bnBC 10 "" $pass | tr -d ':\n')

# 3. Generate the signing key
signing_key=$(openssl rand -base64 48 | tr -d "=+/" | head -c 32)

helm install kargo oci://ghcr.io/akuity/kargo-charts/kargo \
  --namespace kargo \
  --create-namespace \
  --set api.adminAccount.passwordHash="$hashed_pass" \
  --set api.adminAccount.tokenSigningKey="$signing_key" \
  --wait

kubectl port-forward -n kargo svc/kargo-api 8081:443 >/dev/null 2>&1 &

kubectl create namespace traces-test --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace traces-test kargo.akuity.io/project=true --overwrite

# 4. Setup Git credentials for Kargo
echo "🔑 Setting up Git credentials for Kargo..."
kubectl delete secret git-credentials -n elastic-agent-kargo --ignore-not-found

kubectl create secret generic git-credentials \
  --namespace elastic-agent-kargo \
  --from-literal=username=tijnsemmekrot \
  --from-literal=password=${GITHUB_TOKEN} \
  --type=kubernetes.io/basic-auth

# CRITICAL: URL must match exactly what's in kargo-project.yaml (no .git suffix)
kubectl annotate secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/repo-url="${REPO_URL}" \
  --overwrite

kubectl label secret git-credentials \
  --namespace elastic-agent-kargo \
  kargo.akuity.io/cred-type=git \
  --overwrite

# 5. Create ECR credentials for Kargo Warehouse
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

# 6. Grant Kargo access to secrets
echo "🔐 Granting Kargo access to secrets..."
kubectl create rolebinding kargo-controller-secret-reader \
  --clusterrole=kargo-project-secrets-reader \
  --serviceaccount=kargo:kargo-controller-manager \
  --namespace elastic-agent-kargo \
  --dry-run=client -o yaml | kubectl apply -f -

# 4. Apply Kargo Manifests
kubectl apply -f "$SCRIPT_DIR/traces-test/kargo"
