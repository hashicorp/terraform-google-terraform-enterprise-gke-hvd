# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Provider
#------------------------------------------------------------------------------
variable "region" {
  type        = string
  description = "GCP region (location) to deploy TFE in."
}

#------------------------------------------------------------------------------
# Common
#------------------------------------------------------------------------------
variable "project_id" {
  type        = string
  description = "ID of GCP project to deploy TFE in."
}

variable "friendly_name_prefix" {
  type        = string
  description = "Prefix used to name all GCP resources uniquely. It is most common to use either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name here."

  validation {
    condition     = !strcontains(var.friendly_name_prefix, "tfe")
    error_message = "Value must not contain 'tfe' to avoid redundancy in naming conventions."
  }
}

variable "common_labels" {
  type        = map(string)
  description = "Common labels to apply to all GCP resources."
  default     = {}
}

#------------------------------------------------------------------------------
# TFE configuration settings
#------------------------------------------------------------------------------
variable "tfe_fqdn" {
  type        = string
  description = "Fully qualified domain name of TFE instance. This name should eventually resolve to the TFE load balancer DNS name or IP address and will be what clients use to access TFE."
}

variable "tfe_http_port" {
  type        = number
  description = "HTTP port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 8080
}

variable "tfe_https_port" {
  type        = number
  description = "HTTPS port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 8443
}

variable "tfe_metrics_http_port" {
  type        = number
  description = "HTTP port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 9090
}

variable "tfe_metrics_https_port" {
  type        = number
  description = "HTTPS port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value."
  default     = 9091
}

variable "create_helm_overrides_file" {
  type        = bool
  description = "Boolean to generate a YAML file from template with Helm overrides values for your TFE deployment. Set this to `false` after your initial TFE deployment is complete, as we no longer want the Terraform module to manage it (since you will be customizing it further)."
  default     = true
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
variable "vpc_name" {
  type        = string
  description = "Name of existing VPC network to create resources in."
}

variable "vpc_project_id" {
  type        = string
  description = "ID of GCP Project where the existing VPC resides if it is different than the default project."
  default     = null
}

variable "create_tfe_lb_ip" {
  type        = bool
  description = "Boolean to create a static IP address for TFE load balancer (load balancer is created/managed by Helm/Kubernetes)."
  default     = true
}

variable "tfe_lb_ip_address_type" {
  type        = string
  description = "Type of IP address to assign to TFE load balancer. Valid values are 'INTERNAL' or 'EXTERNAL'."
  default     = "INTERNAL"

  validation {
    condition     = var.tfe_lb_ip_address_type == "INTERNAL" || var.tfe_lb_ip_address_type == "EXTERNAL"
    error_message = "Value must either be 'INTERNAL' or 'EXTERNAL'."
  }
}

variable "tfe_lb_subnet_name" {
  type        = string
  description = "Name or self_link to existing VPC subnetwork to create TFE internal load balancer IP address in."
  default     = null

  validation {
    condition     = var.create_tfe_lb_ip && var.tfe_lb_ip_address_type == "INTERNAL" ? var.tfe_lb_subnet_name != null : true
    error_message = "Must provide a value when `create_tfe_lb_ip` is `true` and `tfe_lb_ip_address_type` is `INTERNAL`."
  }
}

variable "tfe_lb_ip_address" {
  type        = string
  description = "IP address to assign to TFE load balancer. Must be a valid IP address from `tfe_lb_subnet_name` when `tfe_lb_ip_address_type` is `INTERNAL`."
  default     = null

  validation {
    condition     = var.create_tfe_lb_ip && var.tfe_lb_ip_address_type == "INTERNAL" ? var.tfe_lb_ip_address != null : true
    error_message = "Must provide a value when `create_tfe_lb_ip` is `true` and `tfe_lb_ip_address_type` is `INTERNAL`."
  }
}

variable "gke_subnet_name" {
  type        = string
  description = "Name or self_link to existing VPC subnetwork to create GKE cluster in."
  default     = null
}

#------------------------------------------------------------------------------
# DNS
#------------------------------------------------------------------------------
variable "create_tfe_cloud_dns_record" {
  type        = bool
  description = "Boolean to create Google Cloud DNS record for TFE using the value of `tfe_fqdn` for the record name."
  default     = false
}

variable "tfe_cloud_dns_record_ip_address" {
  type        = string
  description = "IP address of DNS record for TFE. Only valid when `create_cloud_dns_record` is `true` and `create_tfe_lb_ip` is `false`."
  default     = null

  validation {
    condition     = var.create_tfe_lb_ip ? var.tfe_cloud_dns_record_ip_address == null : true
    error_message = "Value must be `null` when `create_tfe_lb_ip` is `true`."
  }
}

variable "cloud_dns_zone_name" {
  type        = string
  description = "Name of Google Cloud DNS managed zone to create TFE DNS record in. Only valid when `create_cloud_dns_record` is `true`."
  default     = null
}

#------------------------------------------------------------------------------
# IAM
#------------------------------------------------------------------------------
variable "enable_gke_workload_identity" {
  type        = bool
  description = "Boolean to enable GCP workload identity with GKE cluster."
  default     = true
}

variable "tfe_kube_namespace" {
  type        = string
  description = "Name of Kubernetes namespace for TFE (created by Helm chart). Used to configure GCP workload identity with GKE."
  default     = "tfe"
}

variable "tfe_kube_svc_account" {
  type        = string
  description = "Name of Kubernetes Service Account for TFE (created by Helm chart). Used to configure GCP workload identity with GKE."
  default     = "tfe"
}

#------------------------------------------------------------------------------
# GKE
#------------------------------------------------------------------------------
variable "create_gke_cluster" {
  type        = bool
  description = "Boolean to create a GKE cluster."
  default     = false
}

variable "gke_cluster_is_private" {
  type        = bool
  description = "Boolean indicating if GKE network access is private cluster."
  default     = true
}

variable "gke_cluster_name" {
  type        = string
  description = "Name of GKE cluster to create."
  default     = "tfe-gke-cluster"
}

variable "gke_release_channel" {
  type        = string
  description = "The channel to use for how frequent Kubernetes updates and features are received."
  default     = "REGULAR"
}

variable "gke_remove_default_node_pool" {
  type        = bool
  description = "Boolean to remove the default node pool in GKE cluster."
  default     = true
}

variable "gke_deletion_protection" {
  type        = bool
  description = "Boolean to enable deletion protection on GKE cluster."
  default     = false
}

variable "gke_control_plane_cidr" {
  type        = string
  description = "Control plane IP range of private GKE cluster. Must not overlap with any subnet in GKE cluster's VPC."
  default     = "10.0.10.0/28"
}

variable "gke_control_plane_authorized_cidr" {
  type        = string
  description = "CIDR block allowed to access GKE control plane."
  default     = null
}

variable "gke_l4_ilb_subsetting_enabled" {
  type        = bool
  description = "Boolean to enable layer 4 ILB subsetting on GKE cluster."
  default     = true
}

variable "gke_http_load_balancing_disabled" {
  type        = bool
  description = "Boolean to enable HTTP load balancing on GKE cluster."
  default     = false
}

variable "gke_node_pool_name" {
  type        = string
  description = "Name of node pool to create in GKE cluster."
  default     = "tfe-gke-node-pool"
}

variable "gke_node_count" {
  type        = number
  description = "Number of GKE nodes per zone"
  default     = 1
}

variable "gke_node_type" {
  type        = string
  description = "Size/machine type of GKE nodes."
  default     = "e2-standard-4"
}

#------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#------------------------------------------------------------------------------
variable "tfe_database_password_secret_version" {
  type        = string
  description = "Name of PostgreSQL database password secret to retrieve from GCP Secret Manager."
}

variable "tfe_database_name" {
  type        = string
  description = "Name of TFE PostgreSQL database to create."
  default     = "tfe"
}

variable "tfe_database_user" {
  type        = string
  description = "Name of TFE PostgreSQL database user to create."
  default     = "tfe"
}

variable "tfe_database_parameters" {
  type        = string
  description = "Additional parameters to pass into the TFE database settings for the PostgreSQL connection URI."
  default     = "sslmode=require"
}

variable "postgres_version" {
  type        = string
  description = "PostgreSQL version to use."
  default     = "POSTGRES_16"
}

variable "postgres_availability_type" {
  type        = string
  description = "Availability type of Cloud SQL for PostgreSQL instance."
  default     = "REGIONAL"
}

variable "postgres_machine_type" {
  type        = string
  description = "Machine size of Cloud SQL for PostgreSQL instance."
  default     = "db-custom-4-16384"
}

variable "postgres_disk_size" {
  type        = number
  description = "Size in GB of PostgreSQL disk."
  default     = 50
}

variable "postgres_backup_start_time" {
  type        = string
  description = "HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC."
  default     = "00:00"
}

variable "postgres_ssl_mode" {
  type        = string
  description = "Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance."
  default     = "ENCRYPTED_ONLY"
}

variable "postgres_maintenance_window" {
  type = object({
    day          = number
    hour         = number
    update_track = string
  })
  description = "Optional maintenance window settings for the Cloud SQL for PostgreSQL instance."
  default = {
    day          = 7 # default to Sunday
    hour         = 0 # default to midnight
    update_track = "stable"
  }

  validation {
    condition     = var.postgres_maintenance_window.day >= 0 && var.postgres_maintenance_window.day <= 7
    error_message = "`day` must be an integer between 0 and 7 (inclusive)."
  }

  validation {
    condition     = var.postgres_maintenance_window.hour >= 0 && var.postgres_maintenance_window.hour <= 23
    error_message = "`hour` must be an integer between 0 and 23 (inclusive)."
  }

  validation {
    condition     = contains(["stable", "canary", "week5"], var.postgres_maintenance_window.update_track)
    error_message = "`update_track` must be either 'canary', 'stable', or 'week5'."
  }
}

variable "postgres_insights_config" {
  type = object({
    query_insights_enabled  = bool
    query_plans_per_minute  = number
    query_string_length     = number
    record_application_tags = bool
    record_client_address   = bool
  })
  description = "Configuration settings for Cloud SQL for PostgreSQL insights."
  default = {
    query_insights_enabled  = false
    query_plans_per_minute  = 5
    query_string_length     = 1024
    record_application_tags = false
    record_client_address   = false
  }
}

variable "postgres_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL. Geographic location (region) of key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance."
  default     = null
}

variable "postgres_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance."
  default     = null
}

#------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket
#------------------------------------------------------------------------------
variable "gcs_location" {
  type        = string
  description = "Location of TFE GCS bucket to create."
  default     = "US"

  validation {
    condition     = contains(["US", "EU", "ASIA"], var.gcs_location)
    error_message = "Supported values are 'US', 'EU', and 'ASIA'."
  }
}

variable "gcs_storage_class" {
  type        = string
  description = "Storage class of TFE GCS bucket."
  default     = "MULTI_REGIONAL"
}

variable "gcs_uniform_bucket_level_access" {
  type        = bool
  description = "Boolean to enable uniform bucket level access on TFE GCS bucket."
  default     = true
}

variable "gcs_force_destroy" {
  type        = bool
  description = "Boolean indicating whether to allow force destroying the TFE GCS bucket. GCS bucket can be destroyed if it is not empty when `true`."
  default     = false
}

variable "gcs_versioning_enabled" {
  type        = bool
  description = "Boolean to enable versioning on TFE GCS bucket."
  default     = true
}

variable "gcs_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. Geographic location (region) of the key ring must match the location of the TFE GCS bucket."
  default     = null
}

variable "gcs_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption."
  default     = null
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
variable "redis_tier" {
  type        = string
  description = "The service tier of the Redis instance. Defaults to `STANDARD_HA` for high availability."
  default     = "STANDARD_HA"

  validation {
    condition     = var.redis_tier == "BASIC" || var.redis_tier == "STANDARD_HA"
    error_message = "Value must be either 'BASIC' or 'STANDARD_HA'."
  }
}

variable "redis_version" {
  type        = string
  description = "The version of Redis software."
  default     = "REDIS_7_2"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "The size of the Redis instance in GiB."
  default     = 6
}

variable "redis_auth_enabled" {
  type        = bool
  description = "Boolean to enable authentication on Redis instance."
  default     = true
}

variable "redis_transit_encryption_mode" {
  type        = string
  description = "Determines transit encryption (TLS) mode for Redis instance."
  default     = "DISABLED"

  validation {
    condition     = var.redis_transit_encryption_mode == "SERVER_AUTHENTICATION" || var.redis_transit_encryption_mode == "DISABLED"
    error_message = "Value must either be 'SERVER_AUTHENTICATION' or 'DISABLED'."
  }
}

variable "redis_connect_mode" {
  type        = string
  description = "Network connection mode for Redis instance."
  default     = "PRIVATE_SERVICE_ACCESS"

  validation {
    condition     = var.redis_connect_mode == "PRIVATE_SERVICE_ACCESS" || var.redis_connect_mode == "DIRECT_PEERING"
    error_message = "Invalid value for redis_connect_mode. Allowed values are 'PRIVATE_SERVICE_ACCESS' or 'DIRECT_PEERING'."
  }
}

variable "redis_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE Redis instance. Geographic location (region) of key ring must match the location of the TFE Redis instance."
  default     = null
}

variable "redis_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE Redis instance."
  default     = null
}