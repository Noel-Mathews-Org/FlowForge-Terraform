terraform {
  required_version = ">= 1.8.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.78.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.9.0"
    }
  }
}
