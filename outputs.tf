# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
output "tfe_service_account_key" {
  value       = try(google_service_account_key.tfe[0].private_key, null)
  description = "TFE GCP service account key in JSON format, base64-encoded. Only produced when `enable_gke_workload_identity` is `false`."
  sensitive   = true
}

output "tfe_service_account_email" {
  value       = try(google_service_account.tfe.email, null)
  description = "TFE GCP service account email address. Only produced when `enable_gke_workload_identity` is `true`."
}

#------------------------------------------------------------------------------
# IP address
#------------------------------------------------------------------------------
output "tfe_lb_ip_address" {
  value       = try(google_compute_address.tfe_lb[0].address, null)
  description = "IP address of TFE load balancer."
}

output "tfe_lb_ip_address_name" {
  value       = try(google_compute_address.tfe_lb[0].name, null)
  description = "Name of IP address resource of TFE load balancer."
}

#------------------------------------------------------------------------------
# GKE
#------------------------------------------------------------------------------
output "gke_cluster_name" {
  value       = try(google_container_cluster.tfe[0].name, null)
  description = "Name of TFE GKE cluster."
}

#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------
output "tfe_database_instance_id" {
  value       = google_sql_database_instance.tfe.id
  description = "ID of TFE Cloud SQL for PostgreSQL database instance."
}

output "tfe_database_host" {
  value       = "${google_sql_database_instance.tfe.private_ip_address}:5432"
  description = "IP address and port of TFE Cloud SQL for PostgreSQL database instance."
}

output "tfe_database_password" {
  value       = data.google_secret_manager_secret_version.tfe_database_password.secret_data
  description = "TFE PostgreSQL database password."
  sensitive   = true
}

output "tfe_database_password_base64" {
  value       = base64encode(data.google_secret_manager_secret_version.tfe_database_password.secret_data)
  description = "Base64-encoded TFE PostgreSQL database password."
  sensitive   = true
}

#------------------------------------------------------------------------------
# Object storage
#------------------------------------------------------------------------------
output "tfe_object_storage_google_bucket" {
  value       = google_storage_bucket.tfe.id
  description = "Name of TFE GCS bucket."
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
output "tfe_redis_host" {
  value       = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? "${google_redis_instance.tfe.host}:6378" : google_redis_instance.tfe.host
  description = "Hostname/IP address (and port if non-default) of TFE Redis instance."
}

output "tfe_redis_password" {
  value       = google_redis_instance.tfe.auth_string
  description = "Auth string of TFE Redis instance."
  sensitive   = true
}

output "tfe_redis_password_base64" {
  value       = base64encode(google_redis_instance.tfe.auth_string)
  description = "Base64-encoded auth string of TFE Redis instance."
  sensitive   = true
}

output "redis_server_ca_certs" {
  value       = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? google_redis_instance.tfe.server_ca_certs : null
  description = "CA certificate of TFE Redis instance. Add this to your TFE CA bundle."
}