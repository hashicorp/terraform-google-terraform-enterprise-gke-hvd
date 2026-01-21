# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

locals {
  replica_count                    = var.is_secondary_region_deployment ? 0 : 3
  tfe_sa_email                     = var.is_secondary_region_deployment ? data.google_service_account.tfe[0].email : google_service_account.tfe[0].email
  tfe_database_user                = var.is_secondary_region_deployment ? "<TFE_DATABASE_USER> from primary region deployment" : try(local.tfe_database_username, "")
  tfe_database_name                = var.is_secondary_region_deployment ? "<TFE_DATABASE_NAME> from primary region deployment" : var.tfe_database_name
  tfe_object_storage_google_bucket = var.is_secondary_region_deployment ? "<TFE_OBJECT_STORAGE_GOOGLE_BUCKET> from primary region deployment" : google_storage_bucket.tfe[0].id
}

locals {
  helm_overrides_values = {
    replica_count = local.replica_count

    # GKE Workload Identity
    enable_gke_workload_identity = var.enable_gke_workload_identity
    tfe_service_account_email    = var.enable_gke_workload_identity ? local.tfe_sa_email : ""

    # TFE control plane GKE node pool
    tfe_gke_node_pool = var.create_gke_cluster ? google_container_node_pool.tfe[0].name : "<gke-tfe-node-pool-name>"

    # Kubernetes Service (load balancer) settings
    tfe_lb_type            = var.tfe_lb_ip_address_type == "EXTERNAL" ? "External" : "Internal"
    tfe_lb_ip_address_name = var.create_tfe_lb_ip ? google_compute_address.tfe_lb[0].name : "<google-compute-ip-address-name>"

    # TFE configuration settings
    tfe_hostname           = var.tfe_fqdn
    tfe_http_port          = 8080
    tfe_https_port         = 8443
    tfe_admin_https_port   = 8446
    tfe_metrics_http_port  = 9090
    tfe_metrics_https_port = 9091

    # Database settings
    tfe_database_host                                        = "${google_sql_database_instance.tfe.private_ip_address}:5432"
    tfe_database_name                                        = local.tfe_database_name
    tfe_database_user                                        = local.tfe_database_user
    tfe_database_parameters                                  = var.tfe_database_parameters
    tfe_database_passwordless_google_use_default_credentials = var.enable_passwordless_iam_db_auth

    # Object storage settings
    tfe_object_storage_type           = "google"
    tfe_object_storage_google_bucket  = local.tfe_object_storage_google_bucket
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
