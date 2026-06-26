variable "env" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "appgw_id" { type = string }
variable "postgres_id" { type = string }
variable "redis_id" { type = string }
variable "kv_id" { type = string }
variable "alert_email" { type = string }
variable "devops_group_object_id" { type = string }

variable "tags" {
  type    = map(string)
  default = {}
}
