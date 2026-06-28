$token = az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv
(Get-Content db-job-robust.yaml) -replace '__TOKEN__', $token | Set-Content db-job-applied.yaml
kubectl delete configmap db-setup-sql --ignore-not-found
kubectl delete job db-setup-job-v2 --ignore-not-found
kubectl apply -f db-job-applied.yaml
