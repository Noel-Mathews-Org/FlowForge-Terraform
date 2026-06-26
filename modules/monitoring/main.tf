resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.env}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags = merge({
    Env   = var.env
    Layer = "hub ${var.env}"
  }, var.tags)
}

resource "azurerm_application_insights" "appinsights" {
  name                = "appi-${var.env}-hub"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
  tags = merge({
    Env   = var.env
    Layer = "hub ${var.env}"
  }, var.tags)
}


resource "azurerm_role_assignment" "law_reader" {
  scope                = azurerm_log_analytics_workspace.law.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = var.devops_group_object_id
}


resource "azurerm_log_analytics_workspace_table" "container_log_v2" {
  workspace_id = azurerm_log_analytics_workspace.law.id
  name         = "ContainerLogV2"
  plan         = "Basic"
}

resource "azurerm_log_analytics_workspace_table" "container_log" {
  workspace_id = azurerm_log_analytics_workspace.law.id
  name         = "ContainerLog"
  plan         = "Basic"
}


resource "azurerm_monitor_action_group" "main" {
  name                = "ag-flowforge-${var.env}"
  resource_group_name = var.resource_group_name
  short_name          = "ff-alerts"

  email_receiver {
    name          = "SendtoAdmin"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_metric_alert" "appgw_5xx" {
  name                = "alert-appgw-5xx-${var.env}"
  resource_group_name = var.resource_group_name
  scopes              = [var.appgw_id]
  description         = "Action will be triggered when 5xx Error count is greater than 10."

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "FailedRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
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

  action {
    action_group_id = azurerm_monitor_action_group.main.id
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

  action {
    action_group_id = azurerm_monitor_action_group.main.id
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

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
