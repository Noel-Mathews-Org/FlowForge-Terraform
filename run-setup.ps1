$token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
(Get-Content db-job-robust.yaml) -replace '__TOKEN__', $token | Set-Content db-job-applied.yaml
az aks command invoke --resource-group Noel-RG --name aks-22o4pc --file db-job-applied.yaml --command "kubectl delete configmap db-setup-sql --ignore-not-found && kubectl delete job db-setup-job --ignore-not-found && kubectl apply -f db-job-applied.yaml"
