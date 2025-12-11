# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# GKE
#------------------------------------------------------------------------------
output "gke_cluster_name" {
  value       = module.tfe.gke_cluster_name
  description = "Name of TFE GKE cluster."
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
output "tfe_service_account_email" {
  value       = module.tfe.tfe_service_account_email
  description = "TFE GCP service account email address for workload identity."
}

#------------------------------------------------------------------------------
# IP address
#------------------------------------------------------------------------------
output "tfe_lb_ip_address_name" {
  value       = module.tfe.tfe_lb_ip_address_name
  description = "Name of IP address resource of TFE load balancer."
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "tfe_database_host" {
  value       = module.tfe.tfe_database_host
  description = "IP address of TFE Cloud SQL for PostgreSQL database instance."
}

output "tfe_database_password" {
  value       = module.tfe.tfe_database_password
  description = "TFE PostgreSQL database password."
  sensitive   = true
}

output "tfe_database_password_base64" {
  value       = module.tfe.tfe_database_password_base64
  description = "Base64-encoded TFE PostgreSQL database password."
  sensitive   = true
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "tfe_object_storage_google_bucket" {
  value       = module.tfe.tfe_object_storage_google_bucket
  description = "Name of TFE GCS bucket."
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
output "tfe_redis_host" {
  value       = module.tfe.tfe_redis_host
  description = "Hostname/IP address of TFE Redis instance."
}

output "tfe_redis_password" {
  value       = module.tfe.tfe_redis_password
  description = "Base64-encoded auth string of TFE Redis instance."
  sensitive   = true
}

output "tfe_redis_password_base64" {
  value       = module.tfe.tfe_redis_password_base64
  description = "Base64-encoded auth string of TFE Redis instance."
  sensitive   = true
}

output "redis_server_ca_certs" {
  value       = module.tfe.redis_server_ca_certs
  description = "Redis server CA certificates. Add this to your TFE CA bundle."
}