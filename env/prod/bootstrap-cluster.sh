#!/bin/bash
set -e

echo "🚀 Starting Cluster Bootstrap..."

# 1. Fetch AKS Credentials dynamically from Terraform state
echo "🔐 Fetching AKS Credentials..."
AKS_CMD=$(terraform output -raw aks_kubeconfig_command)
eval $AKS_CMD

# 2. Install ArgoCD using custom system-node tolerations
echo "⚓ Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f ../../FlowForge-Helm/infra/argo-values.yaml

# Wait for ArgoCD CRDs to be established
echo "⏳ Waiting for ArgoCD CRDs to register..."
sleep 15

# 3. Apply the Root Infrastructure App of Apps
echo "🏗️ Applying GitOps Infrastructure Root App..."
kubectl apply -f ../../FlowForge-Helm/argocd/infra-root-app.yaml

# 4. Apply the Dev and Prod Application GitOps pipelines
echo "🌐 Applying Dev & Prod Microservice Apps..."
kubectl apply -f ../../FlowForge-Helm/argocd/argocd-dev-app.yaml
kubectl apply -f ../../FlowForge-Helm/argocd/argocd-prod-app.yaml

echo "✅ Bootstrap Complete! ArgoCD is now rebuilding your entire infrastructure."
