Write-Host "🚀 Starting Cluster Bootstrap..."

# 1. Fetch AKS Credentials dynamically from Terraform state
Write-Host "🔐 Fetching AKS Credentials..."
$AKS_CMD = terraform output -raw aks_kubeconfig_command
Invoke-Expression $AKS_CMD

# 2. Install ArgoCD using custom system-node tolerations
Write-Host "⚓ Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd `
  --create-namespace `
  -f ../../FlowForge-Helm/infra/argo-values.yaml

# Wait for ArgoCD CRDs to be established
Write-Host "⏳ Waiting for ArgoCD CRDs to register (15s)..."
Start-Sleep -Seconds 15

# 3. Apply the Root Infrastructure App of Apps
Write-Host "🏗️ Applying GitOps Infrastructure Root App..."
kubectl apply -f ../../FlowForge-Helm/argocd/infra-root-app.yaml

# 4. Apply the Dev and Prod Application GitOps pipelines
Write-Host "🌐 Applying Dev & Prod Microservice Apps..."
kubectl apply -f ../../FlowForge-Helm/argocd/argocd-dev-app.yaml
kubectl apply -f ../../FlowForge-Helm/argocd/argocd-prod-app.yaml

Write-Host "✅ Bootstrap Complete! ArgoCD is now rebuilding your entire infrastructure."
