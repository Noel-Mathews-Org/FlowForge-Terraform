variable "environment" {
  type = string
}

variable "domain" {
  type = string
}

variable "location" {
  type = string
}

variable "hub_vnet_cidr" {
  type = string
}

variable "bastion_subnet_cidr" {
  type = string
}

variable "management_subnet_cidr" {
  type = string
}

variable "gateway_subnet_cidr" {
  type = string
}

variable "fw_subnet_cidr" {
  type = string
}

variable "spoke_vnet_cidr" {
  type = string
}

variable "appgw_subnet_cidr" {
  type = string
}

variable "aks_subnet_cidr" {
  type = string
}

variable "pe_subnet_cidr" {
  type = string
}

variable "db_subnet_cidr" {
  type = string
}

variable "vpn_client_address_pool" {
  type = string
}

variable "entra_audience" {
  type = string
}

variable "aks_system_vm_size" {
  type = string
}

variable "aks_user_vm_size" {
  type = string
}

variable "aks_system_zones" {
  type = list(string)
}

variable "aks_user_zones" {
  type = list(string)
}

variable "postgres_sku" {
  type = string
}

variable "postgres_version" {
  type = string
}

variable "postgres_storage_mb" {
  type = number
}

variable "postgres_storage_tier" {
  type = string
}

variable "redis_enterprise_sku" {
  type = string
}

variable "aks_allowed_fqdns" {
  type = list(string)
}

variable "postgres_admin_username" {
  type = string
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}

variable "devops_group_object_id" {
  type = string
}

variable "devtest_group_object_id" {
  type = string
}

variable "jumpbox_admin_password" {
  type      = string
  sensitive = true
}

variable "jumpbox_vm_size" {
  type        = string
  description = "VM size for the jumpbox. Must be available in the target region."
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}

variable "alert_email" {
  type        = string
  description = "Email address for Azure Monitor alerts"
}

variable "kubernetes_version" { type = string }
variable "aks_sku_tier" { type = string }

variable "jumpbox_zone" { type = string }
