output "app_identity_client_ids" {
  description = "The Workload Identity Client IDs per environment"
  value       = { for k, v in azurerm_user_assigned_identity.app_identity : k => v.client_id }
}

output "azure_tenant_id" {
  description = "The Azure Tenant ID to put in values-common.yaml"
  value       = data.azurerm_client_config.current.tenant_id
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
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server of the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "github_actions_client_id" {
  description = "Client ID of the GitHub Actions Managed Identity for pushing to ACR"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "postgres_connection_string" {
  description = "Ready-to-use DATABASE_URL for Postgres"
  value       = "database-url=postgresql+asyncpg://${module.databases.postgres_admin_username}:${urlencode(var.postgres_admin_password)}@${module.databases.postgres_fqdn}:5432/postgres?ssl=require"
  sensitive   = true
}

output "redis_endpoint" {
  description = "Ready-to-use REDIS_URL"
  value       = "redis-url=rediss://:${module.databases.redis_primary_access_key}@${module.databases.redis_hostname}:${module.databases.redis_port}"
  sensitive   = true
}
