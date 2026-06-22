resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "mi-${var.aks_cluster_name}-cp"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "aks_dns_contributor" {
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor" # For our P2S to work AKS need to create private dns records so user can access using P2S
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_identity.principal_id
}

resource "time_sleep" "wait_for_rbac" {
  depends_on = [
    azurerm_role_assignment.aks_dns_contributor,
    azurerm_role_assignment.aks_network_contributor
  ]
  create_duration = "90s"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.env}"

  private_cluster_enabled   = true
  private_dns_zone_id       = var.private_dns_zone_id
  local_account_disabled    = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = var.tenant_id
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.aks_system_vm_size
    vnet_subnet_id       = var.aks_subnet_id
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 3
    type                 = "VirtualMachineScaleSets"
    zones                = var.aks_system_zones
    max_pods             = 50
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_identity.id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    outbound_type     = var.aks_outbound_type
    load_balancer_sku = "standard"
  }

  ingress_application_gateway {
    gateway_id = var.appgw_id
  }

  tags = merge({ Env = var.env, Layer = "spoke" }, var.tags)

  depends_on = [
    time_sleep.wait_for_rbac
  ]
}

resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  name                  = "node"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.aks_user_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  auto_scaling_enabled  = true
  min_count             = 2
  max_count             = 3
  max_pods              = 50
  zones                 = var.aks_user_zones
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "agic_appgw" {
  scope                = var.appgw_id
  role_definition_name = "Contributor" # AGIC needs contributor on Application Gateway
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}


resource "azurerm_role_assignment" "agic_rg" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Reader" # AGIC needs Reader on Resource Group
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}


resource "azurerm_role_assignment" "agic_vnet" {
  scope                = var.spoke_vnet_id
  role_definition_name = "Network Contributor" # AGIC needs Network contributor on Vnet
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}
