# Copyright (c) HashiCorp, Inc.
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
  account_id   = "${var.friendly_name_prefix}-tfe-sa"
  display_name = "${var.friendly_name_prefix}-tfe-sa"
  description  = "Custom service account for TFE for GCP GKE workload identity."
}

resource "google_service_account_key" "tfe" {
  count = !var.enable_gke_workload_identity ? 1 : 0

  service_account_id = google_service_account.tfe.name
}

resource "google_service_account_iam_binding" "tfe_workload_identity" {
  count = var.enable_gke_workload_identity ? 1 : 0

  service_account_id = google_service_account.tfe.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.tfe_kube_namespace}/${var.tfe_kube_svc_account}]"
  ]
}

resource "google_storage_bucket_iam_member" "tfe_gcs_object_admin" {
  bucket = google_storage_bucket.tfe.id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

resource "google_storage_bucket_iam_member" "tfe_gcs_reader" {
  bucket = google_storage_bucket.tfe.id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.tfe.email}"
}

#------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL KMS CMEK
#------------------------------------------------------------------------------
// There is no Google-managed service account (service agent) for Cloud SQL,
// so one must be created to allow the Cloud SQL instance to use the CMEK.
// https://cloud.google.com/sql/docs/postgres/configure-cmek
resource "google_project_service_identity" "cloud_sql_sa" {
  count    = var.postgres_kms_cmek_name != null ? 1 : 0
  provider = google-beta

  service = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_binding" "cloud_sql_sa_postgres_cmek" {
  count = var.postgres_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.postgres[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_project_service_identity.cloud_sql_sa[0].email}",
  ]
}

#------------------------------------------------------------------------------
# GCS KMS CMEK
#------------------------------------------------------------------------------
locals {
  gcs_service_account_email = "service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_binding" "gcp_project_gcs_cmek" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.tfe_gcs_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${local.gcs_service_account_email}",
  ]
}

#------------------------------------------------------------------------------
# Redis KMS CMEK
#------------------------------------------------------------------------------
locals {
  redis_service_account_email = "service-${data.google_project.current.number}@cloud-redis.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_binding" "redis_sa_cmek" {
  count = var.redis_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.redis[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${local.redis_service_account_email}",
  ]
}
