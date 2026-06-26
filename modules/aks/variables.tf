variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "env" { type = string }
variable "aks_subnet_id" { type = string }
variable "appgw_id" { type = string }
variable "spoke_vnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "aks_system_vm_size" { type = string }
variable "aks_user_vm_size" { type = string }
variable "aks_system_zones" { type = list(string) }
variable "aks_user_zones" { type = list(string) }
variable "spoke_resource_group_name" { type = string }
variable "aks_outbound_type" {
  type    = string
  default = "loadBalancer"
}
variable "private_dns_zone_id" { type = string }
variable "tenant_id" { type = string }
variable "aks_cluster_name" { type = string }
variable "devops_group_object_id" { type = string }
variable "devtest_group_object_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}

variable "kubernetes_version" { type = string }
variable "sku_tier" { type = string }
