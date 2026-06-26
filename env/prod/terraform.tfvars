environment             = "prod"
domain                  = "flowforge.fun"
location                = "centralindia"
hub_vnet_cidr           = "10.0.0.0/20"
bastion_subnet_cidr     = "10.0.1.0/27"
management_subnet_cidr  = "10.0.2.0/24"
gateway_subnet_cidr     = "10.0.3.0/27"
fw_subnet_cidr          = "10.0.4.0/26"
spoke_vnet_cidr         = "10.1.0.0/20"
appgw_subnet_cidr       = "10.1.1.0/24"
aks_subnet_cidr         = "10.1.2.0/23"
pe_subnet_cidr          = "10.1.4.0/24"
db_subnet_cidr          = "10.1.5.0/24"
vpn_client_address_pool = "172.16.0.0/24"
entra_audience          = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
aks_system_vm_size      = "Standard_D2s_v3"
aks_user_vm_size        = "Standard_D2s_v4"
aks_system_zones        = ["2", "3"]
aks_user_zones          = ["2", "3"]
kubernetes_version      = "1.35"
aks_sku_tier            = "Standard"
postgres_sku            = "GP_Standard_D2ds_v5"
postgres_version        = "16"
postgres_storage_mb     = 131072
postgres_storage_tier   = "P10"
redis_enterprise_sku    = "Balanced_B1"
aks_allowed_fqdns = [
  "*.azure.com", "*.docker.io", "docker.io", "production.cloudflare.docker.com", "production.cloudfront.docker.com", "mcr.microsoft.com", "*.ubuntu.com", "*.ghcr.io", "ghcr.io", "*.azurecr.io", "*.pkg.dev", "*.helm.sh", "*.githubusercontent.com",
  "github.com", "api.github.com", "*.github.com", "actions.github.com", "*.quay.io", "quay.io", "*.letsencrypt.org", "letsencrypt.org", "*.k8s.io", "registry.k8s.io",
  "*.azmk8s.io", "login.microsoftonline.com", "packages.microsoft.com", "*.data.mcr.microsoft.com", "*.cdn.mscr.io", "acs-mirror.azureedge.net",
  "*.ecr.aws", "public.ecr.aws", "*.cloudfront.net",
  "*.monitor.azure.com", "*.in.applicationinsights.azure.com", "dc.services.visualstudio.com",
  "grafana.com", "*.grafana.com", "*.github.io", "*.amazonaws.com", "hooks.slack.com"
]
alert_email             = "noelmathews123@gmail.com"
devops_group_object_id  = "76404b8f-f4c9-4627-b922-ce1f6e8f6197"
devtest_group_object_id = "bf0983af-867a-4920-8525-d8d62f718c86"
jumpbox_vm_size         = "Standard_D2as_v4"
jumpbox_zone            = "2"
tags = {
  Project = "FlowForge"
  Owner   = "Noel"
}
