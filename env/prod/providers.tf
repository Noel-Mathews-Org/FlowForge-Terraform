terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.77.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "NoelSTS-RG"
    storage_account_name = "noelsts0910"
    container_name       = "statefile"
    key                  = "prod.terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}
