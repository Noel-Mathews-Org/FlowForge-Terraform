resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.env}-spoke"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.spoke_vnet_cidr]
  tags = merge({
    Env   = var.env
    Layer = "spoke ${var.env}"
  }, var.tags)
}

resource "azurerm_subnet" "appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.appgw_subnet_cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.aks_subnet_cidr]
}

resource "azurerm_subnet" "pe" {
  name                              = "snet-pe"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = [var.pe_subnet_cidr]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.db_subnet_cidr]

  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_network_security_group" "appgw_nsg" {
  name                = "nsg-appgw-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_GWM"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  tags = merge({ Env = var.env, Layer = "spoke ${var.env}" }, var.tags)
}

resource "azurerm_subnet_network_security_group_association" "appgw_nsg_assoc" {
  subnet_id                 = azurerm_subnet.appgw.id
  network_security_group_id = azurerm_network_security_group.appgw_nsg.id
}

resource "azurerm_network_security_group" "aks_nsg" {
  name                = "nsg-aks-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_AppGW_Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080"]
    source_address_prefix      = var.appgw_subnet_cidr
    destination_address_prefix = "*"
  }

  tags = { Env = var.env, Layer = "spoke ${var.env}" }
}

resource "azurerm_subnet_network_security_group_association" "aks_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks_nsg.id
}

resource "azurerm_network_security_group" "pe_nsg" {
  name                = "nsg-pe-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_AKS_VPN_to_PE"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "10000"]
    source_address_prefixes    = [var.aks_subnet_cidr, var.vpn_client_address_pool]
    destination_address_prefix = "*"
  }

  tags = { Env = var.env, Layer = "spoke ${var.env}" }
}

resource "azurerm_subnet_network_security_group_association" "pe_nsg_assoc" {
  subnet_id                 = azurerm_subnet.pe.id
  network_security_group_id = azurerm_network_security_group.pe_nsg.id
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow_AKS_VPN_to_DB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefixes    = [var.aks_subnet_cidr, var.vpn_client_address_pool]
    destination_address_prefix = "*"
  }

  tags = { Env = var.env, Layer = "spoke ${var.env}" }
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}


resource "azurerm_private_dns_zone_virtual_network_link" "spoke_kv" {
  name                  = "spoke-link-kv"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", var.private_dns_zone_kv_id)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_storage" {
  name                  = "spoke-link-storage"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", var.private_dns_zone_storage_id)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_postgres" {
  name                  = "link-spoke-to-postgres"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", var.private_dns_zone_postgres_id)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_aks" {
  name                  = "link-spoke-to-aks"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", var.private_dns_zone_aks_id)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke_redis" {
  name                  = "spoke-link-redis"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", var.private_dns_zone_redis_id)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
}
