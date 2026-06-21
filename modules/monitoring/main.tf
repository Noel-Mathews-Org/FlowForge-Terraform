resource "azurerm_monitor_metric_alert" "appgw_5xx" {
  name                = "alert-appgw-5xx-${var.env}"
  resource_group_name = var.resource_group_name
  scopes              = [var.appgw_id]
  description         = "Action will be triggered when 5xx count is greater than 10."

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "FailedRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }
}

resource "azurerm_monitor_metric_alert" "postgres_cpu" {
  name                = "alert-postgres-cpu-${var.env}"
  resource_group_name = var.resource_group_name
  scopes              = [var.postgres_id]
  description         = "Action will be triggered when CPU is greater than 80%."

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
}

resource "azurerm_monitor_metric_alert" "redis_memory" {
  name                = "alert-redis-mem-${var.env}"
  resource_group_name = var.resource_group_name
  scopes              = [var.redis_id]
  description         = "Action will be triggered when Memory is greater than 80%."

  criteria {
    metric_namespace = "Microsoft.Cache/RedisEnterprise"
    metric_name      = "usedmemorypercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
}

resource "azurerm_monitor_metric_alert" "kv_availability" {
  name                = "alert-kv-avail-${var.env}"
  resource_group_name = var.resource_group_name
  scopes              = [var.kv_id]
  description         = "Action will be triggered when Availability drops below 100%."

  criteria {
    metric_namespace = "Microsoft.KeyVault/vaults"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
  }
}
