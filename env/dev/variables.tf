variable "environment" {
  type    = string
  default = "dev"
}

variable "domain" {
  type    = string
  default = "flowforge.fun"
}

variable "location" {
  type    = string
  default = "centralindia"
}

variable "hub_vnet_cidr" {
  type    = string
  default = "192.168.0.0/20"
}

variable "bastion_subnet_cidr" {
  type    = string
  default = "192.168.1.0/27"
}

variable "management_subnet_cidr" {
  type    = string
  default = "192.168.2.0/24"
}

variable "gateway_subnet_cidr" {
  type    = string
  default = "192.168.3.0/27"
}

variable "fw_subnet_cidr" {
  type    = string
  default = "192.168.4.0/26"
}

variable "spoke_vnet_cidr" {
  type    = string
  default = "192.168.16.0/20"
}

variable "appgw_subnet_cidr" {
  type    = string
  default = "192.168.17.0/24"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "192.168.18.0/23"
}

variable "pe_subnet_cidr" {
  type    = string
  default = "192.168.20.0/24"
}

variable "db_subnet_cidr" {
  type    = string
  default = "192.168.21.0/24"
}

variable "vpn_client_address_pool" {
  type    = string
  default = "172.16.0.0/24"
}

variable "entra_audience" {
  type    = string
  default = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
}

variable "aks_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "postgres_sku" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "postgres_storage_mb" {
  type    = number
  default = 131072
}

variable "postgres_storage_tier" {
  type    = string
  default = "P10"
}

variable "redis_enterprise_sku" {
  type    = string
  default = "Balanced_B1"
}

variable "aks_allowed_fqdns" {
  type = list(string)
  default = [
    "*.azure.com", "*.docker.io", "docker.io", "production.cloudflare.docker.com", "production.cloudfront.docker.com", "mcr.microsoft.com", "*.ubuntu.com", "*.ghcr.io", "ghcr.io", "*.azurecr.io", "*.pkg.dev", "*.helm.sh", "*.githubusercontent.com",
    "github.com", "api.github.com", "*.quay.io", "quay.io", "*.letsencrypt.org", "letsencrypt.org", "*.k8s.io", "registry.k8s.io",
    "*.azmk8s.io", "login.microsoftonline.com", "packages.microsoft.com", "*.data.mcr.microsoft.com", "*.cdn.mscr.io", "acs-mirror.azureedge.net",
    "*.ecr.aws", "public.ecr.aws", "*.cloudfront.net"
  ]
}

variable "postgres_admin_username" {
  type = string
}

variable "postgres_admin_password" {
  type      = string
  sensitive = true
}

variable "devops_group_object_id" {
  type    = string
  default = "e0703be8-b8c7-4eab-9c3c-73ffc06843b8"
}

variable "devtest_group_object_id" {
  type    = string
  default = "97012306-ede4-4162-8b23-be2a2c886b95"
}

variable "jumpbox_admin_password" {
  type      = string
  sensitive = true
}

variable "jumpbox_vm_size" {
  type        = string
  description = "VM size for the jumpbox. Must be available in the target region."
  default     = "Standard_B2ls_v2"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default = {
    Project = "FlowForge"
    Owner   = "noel.mathews@flowforge.fun"
  }
}
