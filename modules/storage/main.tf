resource "azurerm_storage_account" "sa" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  tags = merge({ Env = var.env, Layer = "data" }, var.tags)
}

resource "azurerm_storage_container" "app_data" {
  name                  = "app-data"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}


resource "azurerm_private_endpoint" "pe_storage" {
  name                = "pe-storage-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-storage"
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "pdzg-storage"
    private_dns_zone_ids = [var.private_dns_zone_storage_id]
  }

  tags = merge({ Env = var.env, Layer = "data" }, var.tags)
}

resource "azurerm_monitor_diagnostic_setting" "storage_diag" {
  name                       = "diag-storage-${var.env}"
  target_resource_id         = "${azurerm_storage_account.sa.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "Transaction"
  }
}

