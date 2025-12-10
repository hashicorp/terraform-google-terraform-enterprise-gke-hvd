# Copyright IBM Corp. 2024, 2025
# SPDX-License-Identifier: MPL-2.0

data "google_dns_managed_zone" "tfe" {
  count = var.create_tfe_cloud_dns_record && var.cloud_dns_zone_name != null ? 1 : 0

  name = var.cloud_dns_zone_name
}

locals {
  tfe_dns_record_name = !endswith(var.tfe_fqdn, ".") ? "${var.tfe_fqdn}." : var.tfe_fqdn
}

resource "google_dns_record_set" "tfe" {
  count = var.create_tfe_cloud_dns_record && var.cloud_dns_zone_name != null ? 1 : 0

  managed_zone = data.google_dns_managed_zone.tfe[0].name
  name         = local.tfe_dns_record_name
  type         = "A"
  ttl          = 60
  rrdatas      = var.create_tfe_lb_ip ? [google_compute_address.tfe_lb[0].address] : [var.tfe_cloud_dns_record_ip_address]
}