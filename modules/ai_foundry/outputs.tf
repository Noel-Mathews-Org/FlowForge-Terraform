output "cognitive_account_id" {
  value       = azurerm_cognitive_account.ai.id
  description = "The ID of the Cognitive Services Account"
}

output "cognitive_account_endpoint" {
  value       = azurerm_cognitive_account.ai.endpoint
  description = "The endpoint URL of the Cognitive Services Account"
}
