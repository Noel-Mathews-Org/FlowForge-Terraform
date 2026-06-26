variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "env" { type = string }
variable "pe_subnet_id" { type = string }
variable "private_dns_zone_kv_id" { type = string }
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "tenant_id" { type = string }

variable "key_vault_name" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
