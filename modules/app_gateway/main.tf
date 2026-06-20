resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = { Env = var.env, Layer = "spoke ${var.env}" }
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  frontend_port {
    name = "fe-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "fe-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name = "be-pool"
  }

  backend_http_settings {
    name                  = "be-htst"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "httplstn"
    frontend_ip_configuration_name = "fe-ip-config"
    frontend_port_name             = "fe-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rqrt"
    rule_type                  = "Basic"
    http_listener_name         = "httplstn"
    backend_address_pool_name  = "be-pool"
    backend_http_settings_name = "be-htst"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  tags = { Env = var.env, Layer = "spoke ${var.env}" }

  # Ignore changes made by AGIC
  lifecycle {
    ignore_changes = [
      backend_address_pool,
      backend_http_settings,
      http_listener,
      request_routing_rule,
      probe,
      redirect_configuration,
      ssl_certificate,
      url_path_map
    ]
  }
}

