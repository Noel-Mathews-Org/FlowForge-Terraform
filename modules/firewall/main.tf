resource "azurerm_subnet" "fw" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.hub_vnet_name
  address_prefixes     = [var.fw_subnet_cidr]
}

resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-fw-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { Env = var.env, Layer = "hub" }
}

resource "azurerm_firewall_policy" "fw_policy" {
  name                = "fw-policy-${var.env}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall" "fw" {
  name                = "fw-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }

  tags = merge({ Env = var.env, Layer = "hub" }, var.tags)
}

resource "azurerm_virtual_network_dns_servers" "hub_dns" {
  virtual_network_id = var.hub_vnet_id
  dns_servers        = [azurerm_firewall.fw.ip_configuration[0].private_ip_address]
}

resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_rcg" {
  name               = "fw-policy-rcg-${var.env}"
  firewall_policy_id = azurerm_firewall_policy.fw_policy.id
  priority           = 100

  application_rule_collection {
    name     = "aks-app-rules"
    priority = 100
    action   = "Allow"

    rule {
      name              = "AllowAKSReqs"
      source_addresses  = [var.aks_subnet_cidr]
      destination_fqdns = var.aks_allowed_fqdns
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }

    rule {
      name                  = "AllowAKSFQDNTags"
      source_addresses      = [var.aks_subnet_cidr]
      destination_fqdn_tags = ["AzureKubernetesService"]
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }

  network_rule_collection {
    name     = "aks-net-rules"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "AllowAKS_UDP"
      source_addresses      = [var.aks_subnet_cidr]
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["1194"]
      protocols             = ["UDP"]
    }
    rule {
      name                  = "AllowAKS_TCP"
      source_addresses      = [var.aks_subnet_cidr]
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["9000"]
      protocols             = ["TCP"]
    }
    rule {
      name                  = "AllowAKS_API"
      source_addresses      = [var.aks_subnet_cidr]
      destination_addresses = ["AzureCloud"]
      destination_ports     = ["443", "80"]
      protocols             = ["TCP"]
    }
    rule {
      name                  = "AllowAKS_SMTP"
      source_addresses      = [var.aks_subnet_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["465", "587"]
      protocols             = ["TCP"]
    }
    rule {
      name                  = "AllowNTP"
      source_addresses      = [var.aks_subnet_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
      protocols             = ["UDP"]
    }
    rule {
      name                  = "AllowDB_to_EntraID"
      source_addresses      = [var.db_subnet_cidr]
      destination_addresses = ["AzureActiveDirectory"]
      destination_ports     = ["443"]
      protocols             = ["TCP"]
    }
  }

  network_rule_collection {
    name     = "vpn-to-spoke-rules"
    priority = 300
    action   = "Allow"

    rule {
      name                  = "AllowVPNtoSpoke"
      source_addresses      = [var.vpn_client_address_pool]
      destination_addresses = [var.spoke_vnet_cidr]
      destination_ports     = ["80", "443", "5432", "10000", "22"]
      protocols             = ["TCP"]
    }
  }
}


resource "azurerm_route_table" "spoke_rt" {
  name                          = "rt-spoke-${var.env}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true

  route {
    name                   = "RouteToFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }

  tags = merge({ Env = var.env, Layer = "hub" }, var.tags)
}


resource "azurerm_subnet_route_table_association" "aks" {
  subnet_id      = var.aks_subnet_id
  route_table_id = azurerm_route_table.spoke_rt.id
}

resource "azurerm_subnet_route_table_association" "pe" {
  subnet_id      = var.pe_subnet_id
  route_table_id = azurerm_route_table.spoke_rt.id
}

.
resource "azurerm_route_table" "db_rt" {
  name                          = "rt-db-${var.env}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = true


  route {
    name           = "DirectReturnToVPNClients"
    address_prefix = var.vpn_client_address_pool
    next_hop_type  = "VnetLocal"
  }


  route {
    name                   = "RouteToFirewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
  }

  tags = merge({ Env = var.env, Layer = "hub" }, var.tags)
}

resource "azurerm_subnet_route_table_association" "db" {
  subnet_id      = var.db_subnet_id
  route_table_id = azurerm_route_table.db_rt.id
}

