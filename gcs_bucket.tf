# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket
#------------------------------------------------------------------------------
resource "random_id" "gcs_suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "tfe" {
  count = var.is_secondary_region_deployment ? 0 : 1

  name                        = lower("${var.friendly_name_prefix}-tfe-gcs-${random_id.gcs_suffix.hex}")
  location                    = var.gcs_location
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  public_access_prevention    = var.gcs_public_access_prevention
  force_destroy               = var.gcs_force_destroy
  rpo                         = var.gcs_rpo
  labels                      = var.common_labels

  versioning {
    enabled = var.gcs_versioning_enabled
  }

  dynamic "custom_placement_config" {
    for_each = var.gcs_custom_dual_region_locations != null ? [1] : []

    content {
      data_locations = var.gcs_custom_dual_region_locations
    }
  }

  dynamic "encryption" {
    for_each = var.gcs_kms_cmek_name != null ? [1] : []

    content {
      default_kms_key_name = data.google_kms_crypto_key.tfe_gcs_cmek[0].id
    }
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_sa_cmek]
}

#------------------------------------------------------------------------------
# KMS customer managed encryption key (CMEK) + IAM
#------------------------------------------------------------------------------
data "google_kms_key_ring" "tfe_gcs_cmek" {
  count = var.gcs_kms_keyring_name != null ? 1 : 0

  name     = var.gcs_kms_keyring_name
  location = lower(var.gcs_location)
}

data "google_kms_crypto_key" "tfe_gcs_cmek" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0

  name     = var.gcs_kms_cmek_name
  key_ring = data.google_kms_key_ring.tfe_gcs_cmek[0].id
}

data "google_storage_project_service_account" "gcs" {
  count = var.gcs_kms_keyring_name != null && var.gcs_kms_cmek_name != null ? 1 : 0

  project = data.google_project.current.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_sa_cmek" {
  count = var.gcs_kms_keyring_name != null && var.gcs_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.tfe_gcs_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs[0].email_address}"
}