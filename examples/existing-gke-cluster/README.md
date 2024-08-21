# Example - Existing GKE Cluster

```hcl
module "tfe" {
  source = "path/to/module"

  # --- Common --- #
  project_id           = var.project_id
  friendly_name_prefix = var.friendly_name_prefix

  # --- Networking --- #
  vpc_name           = var.vpc_name
  create_tfe_lb_ip   = var.create_tfe_lb_ip
  tfe_lb_ip_address  = var.tfe_lb_ip_address
  tfe_lb_subnet_name = var.tfe_lb_subnet_name

  # --- DNS --- #
  create_tfe_cloud_dns_record = var.create_tfe_cloud_dns_record
  cloud_dns_zone_name         = var.cloud_dns_zone_name

  # --- TFE config settings --- #
  tfe_fqdn                   = var.tfe_fqdn
  create_helm_overrides_file = var.create_helm_overrides_file

  # --- Database --- #
  tfe_database_password_secret_version = var.tfe_database_password_secret_version
}
```