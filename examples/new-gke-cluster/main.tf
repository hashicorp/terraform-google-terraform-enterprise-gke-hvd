terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.42"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.42"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "tfe" {
  source = "../.."

  # --- Common --- #
  project_id           = var.project_id
  friendly_name_prefix = var.friendly_name_prefix

  # --- TFE config settings --- #
  tfe_fqdn                   = var.tfe_fqdn
  create_helm_overrides_file = var.create_helm_overrides_file

  # --- Networking --- #
  vpc_name           = var.vpc_name
  create_tfe_lb_ip   = var.create_tfe_lb_ip
  tfe_lb_subnet_name = var.tfe_lb_subnet_name
  tfe_lb_ip_address  = var.tfe_lb_ip_address
  gke_subnet_name    = var.gke_subnet_name

  # --- DNS (optional) --- #
  create_tfe_cloud_dns_record = var.create_tfe_cloud_dns_record
  cloud_dns_zone_name         = var.cloud_dns_zone_name

  # --- GKE --- #
  create_gke_cluster                = var.create_gke_cluster
  gke_cluster_is_private            = var.gke_cluster_is_private
  gke_control_plane_authorized_cidr = var.gke_control_plane_authorized_cidr

  # --- Database --- #
  tfe_database_password_secret_version = var.tfe_database_password_secret_version
}