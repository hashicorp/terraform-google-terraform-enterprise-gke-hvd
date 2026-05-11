# Copyright IBM Corp. 2024, 2026
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# GKE cluster service account
#------------------------------------------------------------------------------
resource "google_service_account" "gke" {
  account_id   = "${var.friendly_name_prefix}-gke-cluster-sa"
  display_name = "${var.friendly_name_prefix}-gke-cluster-sa"
  description  = "Custom service account for GKE cluster."
}

resource "google_project_iam_member" "gke_default_node_sa" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_log_writer" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_metric_writer" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_stackdriver_writer" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_object_viewer" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_artifact_reader" {
  project = data.google_client_config.current.project != null ? data.google_client_config.current.project : var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

#------------------------------------------------------------------------------
# TFE service account
#------------------------------------------------------------------------------
resource "google_service_account" "tfe" {
  count = !var.is_secondary_region_deployment ? 1 : 0

  account_id   = var.tfe_gcp_svc_account_name
  display_name = var.tfe_gcp_svc_account_name
  description  = "Custom service account for TFE for GCP GKE workload identity, GCS bucket permissions, and optional database authentication."
}

// Used for secondary region only
data "google_service_account" "tfe" {
  count = var.is_secondary_region_deployment ? 1 : 0

  project    = var.project_id
  account_id = var.tfe_gcp_svc_account_name
}

resource "google_service_account_key" "tfe" {
  count = !var.enable_gke_workload_identity && !var.is_secondary_region_deployment ? 1 : 0

  service_account_id = google_service_account.tfe[0].name
}

resource "google_service_account_iam_member" "tfe_workload_identity" {
  count = var.enable_gke_workload_identity && !var.is_secondary_region_deployment ? 1 : 0

  service_account_id = google_service_account.tfe[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.tfe_kube_namespace}/${var.tfe_kube_svc_account}]"
}

resource "google_storage_bucket_iam_member" "tfe_gcs_object_admin" {
  count = !var.is_secondary_region_deployment ? 1 : 0

  bucket = google_storage_bucket.tfe[0].id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tfe[0].email}"
}

resource "google_storage_bucket_iam_member" "tfe_gcs_reader" {
  count = !var.is_secondary_region_deployment ? 1 : 0

  bucket = google_storage_bucket.tfe[0].id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.tfe[0].email}"
}

resource "google_project_iam_member" "tfe_cloudsql_instance_user" {
  count = var.enable_passwordless_iam_db_auth && !var.is_secondary_region_deployment ? 1 : 0

  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.tfe[0].email}"
}

resource "google_project_iam_member" "tfe_cloudsql_client" {
  count = var.enable_passwordless_iam_db_auth && !var.is_secondary_region_deployment ? 1 : 0

  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.tfe[0].email}"
}