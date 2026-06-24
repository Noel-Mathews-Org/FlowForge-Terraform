output "app_identity_client_ids" {
  description = "The Workload Identity Client IDs per environment"
  value       = { for k, v in data.azurerm_user_assigned_identity.app_identity : k => v.client_id }
}


output "keyvault_names" {
  value = { for k, v in module.key_vault : k => v.kv_name }
}

output "keyvault_uris" {
  value = { for k, v in module.key_vault : k => v.kv_vault_uri }
}

output "storage_account_names" {
  value = { for k, v in module.storage : k => v.storage_account_name }
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = data.azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = data.azurerm_container_registry.acr.login_server
}

output "github_actions_client_id" {
  description = "Client ID of the GitHub Actions Managed Identity for pushing to ACR"
  value       = data.azurerm_user_assigned_identity.github_actions.client_id
}

output "arc_runner_client_id" {
  description = "Client ID of the ARC Managed Identity for Workload Identity Federation"
  value       = data.azurerm_user_assigned_identity.arc_identity.client_id
}

output "jumpbox_private_ip" {
  description = "The private IP of the jumpbox for SSH access"
  value       = module.jumpbox.jumpbox_private_ip
}

output "aks_kubeconfig_command" {
  description = "Command to get the kubeconfig for the AKS cluster"
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${module.aks.aks_cluster_name} --overwrite-existing"
}

output "app_insights_connection_string" {
  value     = module.hub_network.app_insights_connection_string
  sensitive = true
}

output "app_gateway_public_ip" {
  description = "Public IP Address of the Application Gateway"
  value       = module.app_gateway.appgw_pip_address
}

output "ai_foundry_endpoint" {
  description = "The project endpoint URL of the Azure AI Foundry"
  value       = module.ai_foundry.cognitive_account_endpoint
}

output "ai_identity_client_ids" {
  description = "The Workload Identity Client IDs for Analysis Service per environment"
  value       = { for k, v in data.azurerm_user_assigned_identity.ai_identity : k => v.client_id }
}

output "otel_identity_client_id" {
  description = "Client ID of the OTEL Operator Managed Identity"
  value       = data.azurerm_user_assigned_identity.otel_identity.client_id
}