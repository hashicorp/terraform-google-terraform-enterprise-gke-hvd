# Copyright IBM Corp. 2024, 2026
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.14"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  project_id                     = var.project_id
  friendly_name_prefix           = var.friendly_name_prefix
  is_secondary_region_deployment = var.is_secondary_region_deployment
  common_labels                  = var.common_labels

  # --- TFE config settings --- #
  tfe_fqdn                   = var.tfe_fqdn
  create_helm_overrides_file = var.create_helm_overrides_file

  # --- Networking --- #
  vpc_name               = var.vpc_name
  create_tfe_lb_ip       = var.create_tfe_lb_ip
  tfe_lb_ip_address_type = var.tfe_lb_ip_address_type
  tfe_lb_subnet_name     = var.tfe_lb_subnet_name
  tfe_lb_ip_address      = var.tfe_lb_ip_address
  gke_subnet_name        = var.gke_subnet_name

  # --- DNS (optional) --- #
  create_tfe_cloud_dns_record = var.create_tfe_cloud_dns_record
  cloud_dns_zone_name         = var.cloud_dns_zone_name

  # --- GKE --- #
  create_gke_cluster                = var.create_gke_cluster
  gke_cluster_name                  = var.gke_cluster_name
  gke_cluster_is_private            = var.gke_cluster_is_private
  gke_control_plane_authorized_cidr = var.gke_control_plane_authorized_cidr
  gke_node_type                     = var.gke_node_type
  gke_node_count                    = var.gke_node_count

  # --- Database --- #
  postgres_db_is_replica        = var.postgres_db_is_replica
  postgres_master_instance_name = var.postgres_master_instance_name
  postgres_deletion_protection  = var.postgres_deletion_protection
}