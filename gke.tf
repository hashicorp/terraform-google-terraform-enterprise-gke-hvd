#------------------------------------------------------------------------------
# GKE cluster
#------------------------------------------------------------------------------
resource "google_container_cluster" "tfe" {
  count = var.create_gke_cluster ? 1 : 0

  name    = var.gke_cluster_name
  project = var.project_id

  release_channel {
    channel = var.gke_release_channel
  }

  remove_default_node_pool = var.gke_remove_default_node_pool
  initial_node_count       = 1
  deletion_protection      = var.gke_deletion_protection

  network    = data.google_compute_network.vpc.self_link
  subnetwork = data.google_compute_subnetwork.gke[0].self_link

  dynamic "private_cluster_config" {
    for_each = var.gke_cluster_is_private ? [1] : []

    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.gke_enable_private_endpoint # true
      master_ipv4_cidr_block  = var.gke_control_plane_cidr

      master_global_access_config {
        enabled = false
      }
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false

    dynamic "cidr_blocks" {
      for_each = var.gke_control_plane_authorized_cidr != null ? [1] : []

      content {
        cidr_block = var.gke_control_plane_authorized_cidr
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
# GKE node pool
#------------------------------------------------------------------------------
resource "google_container_node_pool" "tfe" {
  count = var.create_gke_cluster ? 1 : 0

  name       = var.gke_node_pool_name
  cluster    = google_container_cluster.tfe[0].id
  node_count = var.gke_node_count

  node_config {
    preemptible  = true
    machine_type = var.gke_node_type

    # Google recommends custom service accounts that have 
    # cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}