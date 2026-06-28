data "azurerm_resource_group" "main" {
  name = "Noel-RG"
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "hub_network" {
  source                 = "../../modules/hub_network"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = var.location
  env                    = var.environment
  hub_vnet_cidr          = var.hub_vnet_cidr
  bastion_subnet_cidr    = var.bastion_subnet_cidr
  management_subnet_cidr = var.management_subnet_cidr
  devops_group_object_id = var.devops_group_object_id
  tags                   = var.tags
}

module "spoke_network" {
  source                       = "../../modules/spoke_network"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = var.location
  env                          = var.environment
  spoke_vnet_cidr              = var.spoke_vnet_cidr
  appgw_subnet_cidr            = var.appgw_subnet_cidr
  aks_subnet_cidr              = var.aks_subnet_cidr
  pe_subnet_cidr               = var.pe_subnet_cidr
  db_subnet_cidr               = var.db_subnet_cidr
  hub_vnet_id                  = module.hub_network.hub_vnet_id
  hub_vnet_name                = module.hub_network.hub_vnet_name
  hub_resource_group_name      = data.azurerm_resource_group.main.name
  private_dns_zone_kv_id       = module.hub_network.private_dns_zone_kv_id
  private_dns_zone_storage_id  = module.hub_network.private_dns_zone_storage_id
  private_dns_zone_postgres_id = module.hub_network.private_dns_zone_postgres_id
  private_dns_zone_redis_id    = module.hub_network.private_dns_zone_redis_id
  private_dns_zone_aks_id      = module.hub_network.private_dns_zone_aks_id
  vpn_client_address_pool      = var.vpn_client_address_pool
  tags                         = var.tags
}

module "firewall" {
  source                     = "../../modules/firewall"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  env                        = var.environment
  hub_vnet_name              = module.hub_network.hub_vnet_name
  fw_subnet_cidr             = var.fw_subnet_cidr
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  aks_subnet_id              = module.spoke_network.aks_subnet_id
  pe_subnet_id               = module.spoke_network.pe_subnet_id
  db_subnet_id               = module.spoke_network.db_subnet_id
  aks_allowed_fqdns          = var.aks_allowed_fqdns
  hub_vnet_cidr              = var.hub_vnet_cidr
  spoke_vnet_cidr            = var.spoke_vnet_cidr
  vpn_client_address_pool    = var.vpn_client_address_pool
  hub_vnet_id                = module.hub_network.hub_vnet_id
  aks_subnet_cidr            = var.aks_subnet_cidr
  db_subnet_cidr             = var.db_subnet_cidr
  tags                       = var.tags
}

module "vpn_gateway" {
  source                     = "../../modules/vpn_gateway"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  env                        = var.environment
  hub_vnet_name              = module.hub_network.hub_vnet_name
  gateway_subnet_cidr        = var.gateway_subnet_cidr
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  vpn_client_address_pool    = var.vpn_client_address_pool
  entra_tenant_id            = data.azurerm_client_config.current.tenant_id
  entra_audience             = var.entra_audience
  firewall_private_ip        = module.firewall.firewall_private_ip
  spoke_vnet_cidr            = var.spoke_vnet_cidr
  depends_on                 = [module.firewall]
  tags                       = var.tags
}

module "app_gateway" {
  source                     = "../../modules/app_gateway"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  env                        = var.environment
  appgw_subnet_id            = module.spoke_network.appgw_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  tags                       = var.tags
}

module "aks" {
  source                     = "../../modules/aks"
  resource_group_name        = data.azurerm_resource_group.main.name
  location                   = var.location
  env                        = var.environment
  aks_subnet_id              = module.spoke_network.aks_subnet_id
  appgw_id                   = module.app_gateway.appgw_id
  spoke_vnet_id              = module.spoke_network.spoke_vnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  private_dns_zone_id        = module.hub_network.private_dns_zone_aks_id
  kubernetes_version         = var.kubernetes_version
  sku_tier                   = var.aks_sku_tier
  aks_system_vm_size         = var.aks_system_vm_size
  aks_user_vm_size           = var.aks_user_vm_size
  aks_system_zones           = var.aks_system_zones
  aks_user_zones             = var.aks_user_zones
  aks_cluster_name           = "aks-${random_string.suffix.result}"
  spoke_resource_group_name  = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  aks_outbound_type          = "userDefinedRouting"
  devops_group_object_id     = var.devops_group_object_id
  devtest_group_object_id    = var.devtest_group_object_id
  depends_on = [
    module.firewall,
    azurerm_virtual_network_peering.spoke_to_hub,
    azurerm_virtual_network_peering.hub_to_spoke
  ]
  tags = var.tags
}

module "databases" {
  source                       = "../../modules/databases"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = var.location
  env                          = var.environment
  pe_subnet_id                 = module.spoke_network.pe_subnet_id
  db_subnet_id                 = module.spoke_network.db_subnet_id
  private_dns_zone_postgres_id = module.hub_network.private_dns_zone_postgres_id
  private_dns_zone_redis_id    = module.hub_network.private_dns_zone_redis_id
  postgres_sku                 = var.postgres_sku
  postgres_version             = var.postgres_version
  postgres_storage_mb          = var.postgres_storage_mb
  postgres_storage_tier        = var.postgres_storage_tier
  redis_enterprise_sku         = var.redis_enterprise_sku
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id
  postgres_admin_username      = var.postgres_admin_username
  postgres_admin_password      = var.postgres_admin_password
  postgres_server_name         = "pgsql-${random_string.suffix.result}"
  redis_cache_name             = "redis-${random_string.suffix.result}"
  tags                         = var.tags
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  entra_admin_object_id        = var.devops_group_object_id
  entra_admin_principal_name   = "FlowForge-DevOps"
  entra_admin_principal_type   = "Group"
}


module "monitoring" {
  source                 = "../../modules/monitoring"
  env                    = var.environment
  location               = var.location
  resource_group_name    = data.azurerm_resource_group.main.name
  appgw_id               = module.app_gateway.appgw_id
  postgres_id            = module.databases.postgres_id
  redis_id               = module.databases.redis_id
  kv_id                  = module.key_vault["prod"].kv_id
  alert_email            = var.alert_email
  devops_group_object_id = var.devops_group_object_id
  tags                   = var.tags
}

module "key_vault" {
  source   = "../../modules/key_vault"
  for_each = toset(local.environments)

  resource_group_name    = data.azurerm_resource_group.main.name
  location               = var.location
  env                    = each.key
  pe_subnet_id           = module.spoke_network.pe_subnet_id
  private_dns_zone_kv_id = module.hub_network.private_dns_zone_kv_id
  tenant_id              = data.azurerm_client_config.current.tenant_id
  key_vault_name         = "kvlt-${each.key}-${random_string.suffix.result}"
  tags                   = var.tags
}

module "storage" {
  source   = "../../modules/storage"
  for_each = toset(local.environments)

  resource_group_name         = data.azurerm_resource_group.main.name
  location                    = var.location
  env                         = each.key
  pe_subnet_id                = module.spoke_network.pe_subnet_id
  private_dns_zone_storage_id = module.hub_network.private_dns_zone_storage_id
  log_analytics_workspace_id  = module.monitoring.log_analytics_workspace_id
  storage_account_name        = "${random_string.suffix.result}ff${each.key}"
  tags                        = var.tags
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = data.azurerm_resource_group.main.name
  virtual_network_name         = module.spoke_network.spoke_vnet_name
  remote_virtual_network_id    = module.hub_network.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
  depends_on                   = [module.vpn_gateway, module.firewall]
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = data.azurerm_resource_group.main.name
  virtual_network_name         = module.hub_network.hub_vnet_name
  remote_virtual_network_id    = module.spoke_network.spoke_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  depends_on                   = [module.vpn_gateway, module.firewall]
}


module "jumpbox" {
  source              = "../../modules/jumpbox"
  env                 = var.environment
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  subnet_id           = module.hub_network.management_subnet_id
  admin_password      = var.jumpbox_admin_password
  vm_size             = var.jumpbox_vm_size
  jumpbox_zone        = var.jumpbox_zone
  tags                = var.tags
}

module "ai_foundry" {
  source                 = "../../modules/ai_foundry"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = "eastus2"
  cognitive_account_name = "ai-${random_string.suffix.result}"
  model_name             = "summary-agent"
  tags                   = var.tags
}

data "azurerm_container_registry" "acr" {
  name                = "flowforgeacrm9mp04"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull" # AKS need to Pull images
  principal_id         = module.aks.kubelet_identity_object_id
}

resource "azurerm_role_assignment" "github_acr_push" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPush" # CI pipeline need to push image to ACR
  principal_id         = data.azurerm_user_assigned_identity.github_actions.principal_id
}


locals {
  microservices = ["frontend", "gateway", "auth-service", "project-service", "task-service", "notification-worker"]
  environments  = ["dev", "prod"]
  fid_combinations = flatten([
    for env in local.environments : [
      for svc in local.microservices : {
        env = env
        svc = svc
      }
    ]
  ])
}

data "azurerm_user_assigned_identity" "app_identity" {
  for_each            = toset(local.environments)
  name                = "mi-flowforge-app-${each.key}"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "app_fid" {
  for_each                  = { for combo in local.fid_combinations : "${combo.env}-${combo.svc}" => combo }
  name                      = "fid-flowforge-${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.oidc_issuer_url
  user_assigned_identity_id = data.azurerm_user_assigned_identity.app_identity[each.value.env].id
  subject                   = "system:serviceaccount:flowforge-${each.value.env}:flowforge-${each.value.env}-${each.value.svc}"
}


data "azurerm_user_assigned_identity" "github_actions" {
  name                = "mi-github-actions-prod"
  resource_group_name = data.azurerm_resource_group.main.name
}


resource "azurerm_federated_identity_credential" "github_fid_dev_branch" {
  name                      = "fid-github-Cloud-Track-dev"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.github_actions.id
  subject                   = "repo:Noel-Mathews-Org/FlowForge:ref:refs/heads/Cloud-Track-dev"
}

resource "azurerm_federated_identity_credential" "github_fid_prod_env" {
  name                      = "fid-github-env-prod"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  user_assigned_identity_id = data.azurerm_user_assigned_identity.github_actions.id
  subject                   = "repo:Noel-Mathews-Org/FlowForge:environment:prod"
}

data "azurerm_user_assigned_identity" "arc_identity" {
  name                = "mi-arc-runner-m9mp04"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "arc_fid" {
  name                      = "fid-arc-runner"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.oidc_issuer_url
  user_assigned_identity_id = data.azurerm_user_assigned_identity.arc_identity.id
  subject                   = "system:serviceaccount:arc-system:arc-runner-sa"
}

data "azurerm_user_assigned_identity" "otel_identity" {
  name                = "mi-flowforge-otel-m9mp04"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "otel_metrics_publisher" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = data.azurerm_user_assigned_identity.otel_identity.principal_id
}

resource "azurerm_federated_identity_credential" "otel_fid" {
  for_each                  = toset(local.environments)
  name                      = "fid-otel-${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.oidc_issuer_url
  user_assigned_identity_id = data.azurerm_user_assigned_identity.otel_identity.id
  subject                   = "system:serviceaccount:flowforge-${each.key}:otel-collector-sa"
}

data "azurerm_user_assigned_identity" "ai_identity" {
  for_each            = toset(local.environments)
  name                = "mi-ai-${each.key}-m9mp04"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_federated_identity_credential" "ai_fid" {
  for_each                  = toset(local.environments)
  name                      = "fid-ai-${each.key}"
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = module.aks.oidc_issuer_url
  user_assigned_identity_id = data.azurerm_user_assigned_identity.ai_identity[each.key].id
  subject                   = "system:serviceaccount:flowforge-${each.key}:flowforge-${each.key}-analysis-service"
}


resource "azurerm_role_assignment" "ai_openai_user" {
  for_each             = toset(local.environments)
  scope                = module.ai_foundry.cognitive_account_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = data.azurerm_user_assigned_identity.ai_identity[each.key].principal_id
}

resource "azurerm_role_assignment" "ai_kv_secrets_user" {
  for_each             = toset(local.environments)
  scope                = module.key_vault[each.key].kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.ai_identity[each.key].principal_id
}

resource "azurerm_role_assignment" "ai_storage_blob_data_contributor" {
  for_each             = toset(local.environments)
  scope                = module.storage[each.key].storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.ai_identity[each.key].principal_id
}

resource "azurerm_role_assignment" "app_storage_blob_data_contributor" {
  for_each             = toset(local.environments)
  scope                = module.storage[each.key].storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.app_identity[each.key].principal_id
}


resource "azurerm_role_assignment" "app_kv_secrets_user" {
  for_each             = toset(local.environments)
  scope                = module.key_vault[each.key].kv_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_user_assigned_identity.app_identity[each.key].principal_id
}


resource "azurerm_role_assignment" "arc_kv_secrets_officer" {
  for_each             = toset(local.environments)
  scope                = module.key_vault[each.key].kv_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_user_assigned_identity.arc_identity.principal_id
}

resource "azurerm_monitor_diagnostic_setting" "kv_diag" {
  for_each                   = toset(local.environments)
  name                       = "diag-kv-${each.key}"
  target_resource_id         = module.key_vault[each.key].kv_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  depends_on = [module.key_vault, module.monitoring]
}
