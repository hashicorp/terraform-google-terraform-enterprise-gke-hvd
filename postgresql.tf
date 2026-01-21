# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

#------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#------------------------------------------------------------------------------
resource "random_id" "postgres_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "tfe" {
  name                 = "${var.friendly_name_prefix}-tfe-pg-${random_id.postgres_suffix.hex}"
  database_version     = var.postgres_version
  encryption_key_name  = var.postgres_kms_cmek_name == null ? null : data.google_kms_crypto_key.postgres[0].id
  deletion_protection  = var.postgres_deletion_protection
  master_instance_name = var.postgres_db_is_replica ? var.postgres_master_instance_name : null

  settings {
    availability_type = var.postgres_availability_type
    tier              = var.postgres_machine_type
    edition           = var.postgres_edition
    disk_type         = var.postgres_disk_type
    disk_size         = var.postgres_disk_size
    disk_autoresize   = var.postgres_disk_autoresize

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.vpc.self_link
      ssl_mode        = var.postgres_ssl_mode
    }

    dynamic "backup_configuration" {
      for_each = var.postgres_db_is_replica ? [] : [1]

      content {
        enabled                        = var.postgres_backup_config.enabled
        start_time                     = var.postgres_backup_config.start_time
        point_in_time_recovery_enabled = var.postgres_backup_config.point_in_time_recovery_enabled
        transaction_log_retention_days = var.postgres_backup_config.transaction_log_retention_days

        backup_retention_settings {
          retained_backups = var.postgres_backup_config.retained_backups
          retention_unit   = "COUNT"
        }
      }
    }

    dynamic "maintenance_window" {
      for_each = var.postgres_db_is_replica ? [] : [1]

      content {
        day          = var.postgres_maintenance_window.day
        hour         = var.postgres_maintenance_window.hour
        update_track = var.postgres_maintenance_window.update_track
      }
    }

    insights_config {
      query_insights_enabled  = var.postgres_insights_config.query_insights_enabled
      query_plans_per_minute  = var.postgres_insights_config.query_plans_per_minute
      query_string_length     = var.postgres_insights_config.query_string_length
      record_application_tags = var.postgres_insights_config.record_application_tags
      record_client_address   = var.postgres_insights_config.record_client_address
    }

    dynamic "database_flags" {
      for_each = var.enable_passwordless_iam_db_auth ? [1] : []

      content {
        name  = "cloudsql.iam_authentication"
        value = "on"
      }
    }

    user_labels = merge(
      var.common_labels,
      { is_replica = var.postgres_db_is_replica ? "true" : "false" }
    )
  }

  depends_on = [google_kms_crypto_key_iam_member.cloud_sql_sa_postgres_cmek]
}

resource "google_sql_database" "tfe" {
  count = var.is_secondary_region_deployment ? 0 : 1

  name     = var.tfe_database_name
  instance = google_sql_database_instance.tfe.name
}

locals {
  tfe_db_sa_account_id = (
    var.is_secondary_region_deployment
    ? data.google_service_account.tfe[0].account_id
    : google_service_account.tfe[0].account_id
  )

  tfe_db_sa_project = (
    var.is_secondary_region_deployment
    ? data.google_service_account.tfe[0].project
    : google_service_account.tfe[0].project
  )

  # GCP Cloud SQL IAM requires specific format for username
  tfe_database_username = (
    var.enable_passwordless_iam_db_auth
    ? "${local.tfe_db_sa_account_id}@${local.tfe_db_sa_project}.iam"
    : var.tfe_database_user
  )
}

resource "google_sql_user" "tfe" {
  count = var.is_secondary_region_deployment ? 0 : 1

  name     = local.tfe_database_username
  instance = google_sql_database_instance.tfe.name
  type     = var.enable_passwordless_iam_db_auth ? "CLOUD_IAM_SERVICE_ACCOUNT" : null
  password = var.enable_passwordless_iam_db_auth ? null : data.google_secret_manager_secret_version.tfe_database_password[0].secret_data
}

#------------------------------------------------------------------------------
# Google secret manager - optional TFE database password lookup
#------------------------------------------------------------------------------
data "google_secret_manager_secret_version" "tfe_database_password" {
  count = (
    var.is_secondary_region_deployment ||
    var.enable_passwordless_iam_db_auth ||
    var.tfe_database_password_secret_version == null
  ) ? 0 : 1

  secret = var.tfe_database_password_secret_version
}

#------------------------------------------------------------------------------
# KMS customer managed encryption key (CMEK) + IAM
#------------------------------------------------------------------------------
data "google_kms_key_ring" "postgres" {
  count = var.postgres_kms_keyring_name != null ? 1 : 0

  name     = var.postgres_kms_keyring_name
  location = data.google_client_config.current.region
}

data "google_kms_crypto_key" "postgres" {
  count = var.postgres_kms_cmek_name != null ? 1 : 0

  name     = var.postgres_kms_cmek_name
  key_ring = data.google_kms_key_ring.postgres[0].id
}

resource "google_kms_crypto_key_iam_member" "cloud_sql_sa_postgres_cmek" {
  count = var.postgres_kms_cmek_name != null && var.postgres_kms_keyring_name != null && var.cloud_sql_service_agent_email != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.postgres[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.cloud_sql_service_agent_email}"
}