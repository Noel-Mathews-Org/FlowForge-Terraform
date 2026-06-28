resource "azurerm_postgresql_flexible_server" "postgres" {
  name                          = var.postgres_server_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgres_version
  sku_name                      = var.postgres_sku
  storage_mb                    = var.postgres_storage_mb
  storage_tier                  = var.postgres_storage_tier
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false
  delegated_subnet_id           = var.db_subnet_id
  private_dns_zone_id           = var.private_dns_zone_postgres_id
  zone                          = "2"

  high_availability {
    mode = "SameZone"
  }

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = var.tenant_id
  }

  tags = merge({ Env = var.env, Layer = "data" }, var.tags)

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "pgaadauth_ext" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  value     = "pgaadauth"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admin" {
  server_name         = azurerm_postgresql_flexible_server.postgres.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.entra_admin_object_id
  principal_name      = var.entra_admin_principal_name
  principal_type      = var.entra_admin_principal_type
}

resource "azurerm_postgresql_flexible_server_database" "db_dev" {
  name      = "flowforge-dev"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_database" "db_prod" {
  name      = "flowforge-prod"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}



resource "azurerm_managed_redis" "redis" {
  name                  = var.redis_cache_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  sku_name              = var.redis_enterprise_sku
  public_network_access = "Disabled"

  tags = merge({ Env = var.env, Layer = "data" }, var.tags)

  default_database {
    clustering_policy                  = "EnterpriseCluster"
    eviction_policy                    = "VolatileLRU"
    access_keys_authentication_enabled = true
  }
}


resource "azurerm_private_endpoint" "pe_redis" {
  name                = "pe-redis-${var.env}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pe_subnet_id

  private_service_connection {
    name                           = "psc-redis"
    private_connection_resource_id = azurerm_managed_redis.redis.id
    is_manual_connection           = false
    subresource_names              = ["redisEnterprise"]
  }

  private_dns_zone_group {
    name                 = "pdzg-redis"
    private_dns_zone_ids = [var.private_dns_zone_redis_id]
  }

  tags = merge({ Env = var.env, Layer = "data" }, var.tags)
}


resource "azurerm_monitor_diagnostic_setting" "postgres_diag" {
  name                       = "diag-postgres-${var.env}"
  target_resource_id         = azurerm_postgresql_flexible_server.postgres.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }
}

