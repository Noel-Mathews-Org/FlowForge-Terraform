resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.env}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.hub_vnet_cidr]
  tags = merge({
    Env   = var.env
    Layer = "hub ${var.env}"
  }, var.tags)
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.management_subnet_cidr]
}


resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_aks" {
  name                  = "link-hub-to-aks"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags = merge({
    Env   = var.env
    Layer = "hub"
  }, var.tags)
}

resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags = merge({
    Env   = var.env
    Layer = "hub"
  }, var.tags)
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags = merge({
    Env   = var.env
    Layer = "hub"
  }, var.tags)
}

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = var.resource_group_name
  tags = merge({
    Env   = var.env
    Layer = "hub"
  }, var.tags)
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_kv" {
  name                  = "hub-link-kv"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_storage" {
  name                  = "hub-link-storage"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_postgres" {
  name                  = "hub-link-postgres"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_redis" {
  name                  = "hub-link-redis"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = azurerm_virtual_network.hub.id
}
