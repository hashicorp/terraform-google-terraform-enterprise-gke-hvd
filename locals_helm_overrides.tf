# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  helm_overrides_values = {

    # Workload Identity
    enable_gke_workload_identity = var.enable_gke_workload_identity
    tfe_service_account_email    = var.enable_gke_workload_identity ? google_service_account.tfe.email : ""

    # Service (load balancer) settings
    tfe_lb_type       = var.tfe_lb_ip_address_type == "EXTERNAL" ? "External" : "Internal"
    tfe_lb_ip_address = var.create_tfe_lb_ip ? google_compute_address.tfe_lb[0].name : ""

    # TFE configuration settings
    tfe_hostname           = var.tfe_fqdn
    tfe_http_port          = var.tfe_http_port
    tfe_https_port         = var.tfe_https_port
    tfe_metrics_http_port  = var.tfe_metrics_http_port
    tfe_metrics_https_port = var.tfe_metrics_https_port

    # Database settings
    tfe_database_host       = "${google_sql_database_instance.tfe.private_ip_address}:5432"
    tfe_database_name       = var.tfe_database_name
    tfe_database_user       = var.tfe_database_user
    tfe_database_parameters = var.tfe_database_parameters

    # Object storage settings
    tfe_object_storage_type           = "google"
    tfe_object_storage_google_bucket  = google_storage_bucket.tfe.id
    tfe_object_storage_google_project = var.project_id

    # Redis settings
    tfe_redis_host     = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? "${google_redis_instance.tfe.host}:6378" : google_redis_instance.tfe.host
    tfe_redis_use_auth = var.redis_auth_enabled
    tfe_redis_use_tls  = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" ? true : false
  }
}

resource "local_file" "helm_values_values" {
  count = var.create_helm_overrides_file ? 1 : 0

  content  = templatefile("${path.module}/templates/helm_overrides.yaml.tpl", local.helm_overrides_values)
  filename = "${path.cwd}/helm/module_generated_helm_overrides.yaml"

  lifecycle {
    ignore_changes = [content, filename]
  }
}
