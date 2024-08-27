# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Google client config
#------------------------------------------------------------------------------
data "google_client_config" "current" {}

#------------------------------------------------------------------------------
# Google project
#------------------------------------------------------------------------------
data "google_project" "current" {}

#------------------------------------------------------------------------------
# Availability zones
#------------------------------------------------------------------------------
data "google_compute_zones" "up" {
  project = var.project_id
  status  = "UP"
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------
data "google_compute_network" "vpc" {
  name    = var.vpc_name
  project = var.vpc_project_id != null ? var.vpc_project_id : var.project_id
}

data "google_compute_subnetwork" "tfe_lb" {
  count = var.tfe_lb_subnet_name != null ? 1 : 0

  name    = var.tfe_lb_subnet_name
  project = var.vpc_project_id != null ? var.vpc_project_id : var.project_id
}

data "google_compute_subnetwork" "gke" {
  count = var.create_gke_cluster && var.gke_subnet_name != null ? 1 : 0

  name    = var.gke_subnet_name
  project = var.vpc_project_id != null ? var.vpc_project_id : var.project_id
}