variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
}

variable "location" {
  type        = string
  description = "The Azure region for the AI Foundry (e.g. eastus2)"
}

variable "cognitive_account_name" {
  type        = string
  description = "Name of the Cognitive Services account"
}

variable "model_name" {
  type        = string
  description = "Deployment name for the model"
  default     = "summary-agent"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}
