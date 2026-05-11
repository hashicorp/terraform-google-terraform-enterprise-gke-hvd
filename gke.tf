# Copyright IBM Corp. 2024, 2026
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# GKE cluster
#------------------------------------------------------------------------------
resource "google_container_cluster" "tfe" {
  count = var.create_gke_cluster ? 1 : 0

  name            = var.gke_cluster_name
  project         = var.project_id
  resource_labels = var.common_labels

  release_channel {
    channel = var.gke_release_channel
  }

  remove_default_node_pool = var.gke_remove_default_node_pool
  initial_node_count       = 1
  node_locations           = var.gke_cluster_node_locations
  deletion_protection      = var.gke_deletion_protection

  network    = data.google_compute_network.vpc.self_link
  subnetwork = data.google_compute_subnetwork.gke[0].self_link

  dynamic "private_cluster_config" {
    # Only include this block when we want a "private" GKE cluster.
    # When omitted, the control plane has a public endpoint (subject to master_authorized_networks_config).
    for_each = var.gke_cluster_is_private ? [1] : []

    content {
      enable_private_nodes    = true                            # Worker nodes get private IPs only (no public IPs on nodes)
      enable_private_endpoint = var.gke_enable_private_endpoint # Controls whether the K8s API endpoint is private (VPC-only) or public
      master_ipv4_cidr_block  = var.gke_control_plane_cidr      # CIDR range allocated to the GKE control plane

      master_global_access_config {
        # Disallow global (cross-region) access to the control plane endpoint
        enabled = false
      }
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false # Do not auto-allow Google-managed public IP ranges

    dynamic "cidr_blocks" {
      for_each = var.gke_control_plane_authorized_cidr != null ? [1] : [] # Allow your own CIDR ranges

      content {
        cidr_block   = var.gke_control_plane_authorized_cidr
        display_name = "user-defined-authorized-cidr"
      }
    }
  }

  enable_l4_ilb_subsetting = var.gke_l4_ilb_subsetting_enabled

  addons_config {
    http_load_balancing {
      disabled = var.gke_http_load_balancing_disabled
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  logging_service = "logging.googleapis.com/kubernetes"
}

#------------------------------------------------------------------------------
# GKE node pool - TFE control plane
#------------------------------------------------------------------------------
resource "google_container_node_pool" "tfe" {
  count = var.create_gke_cluster ? 1 : 0

  name       = var.gke_node_pool_name
  cluster    = google_container_cluster.tfe[0].id
  node_count = var.gke_node_count

  node_config {
    preemptible  = false
    machine_type = var.gke_node_type
    disk_type    = var.gke_node_disk_type
    disk_size_gb = var.gke_node_disk_size_gb

    # Google recommends custom service accounts that have 
    # cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}