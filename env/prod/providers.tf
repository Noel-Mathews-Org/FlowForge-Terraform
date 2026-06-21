terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.77.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "Noel-STF"
    storage_account_name = "noelstf98"
    container_name       = "statefile"
    key                  = "prod.terraform.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
}
