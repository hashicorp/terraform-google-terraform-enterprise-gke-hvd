# Example - New GKE Cluster (Secondary Region)

This example configuration deploys TFE into a **secondary** GCP region, including the creation of a new GKE cluster. A TFE instance **must already be deployed** in the primary region. If not, refer to the [new-gke-cluster-primary](../new-gke-cluster-primary/) example first.

An [example terraform.tfvars](./terraform.tfvars.example) file is provided as a starting point. Update it with your own values before applying.

```hcl
module "tfe" {
  source  = "hashicorp/terraform-enterprise-gke-hvd/google"
  version = "x.x.x"

  # --- Common --- #
  project_id                     = var.project_id
  friendly_name_prefix           = var.friendly_name_prefix
  is_secondary_region_deployment = var.is_secondary_region_deployment
  common_labels                  = var.common_labels

  # --- TFE config settings --- #
  tfe_fqdn                   = var.tfe_fqdn
  create_helm_overrides_file = var.create_helm_overrides_file

  # --- Networking --- #
  vpc_name               = var.vpc_name
  create_tfe_lb_ip       = var.create_tfe_lb_ip
  tfe_lb_ip_address_type = var.tfe_lb_ip_address_type
  tfe_lb_subnet_name     = var.tfe_lb_subnet_name
  tfe_lb_ip_address      = var.tfe_lb_ip_address
  gke_subnet_name        = var.gke_subnet_name

  # --- DNS (optional) --- #
  create_tfe_cloud_dns_record = var.create_tfe_cloud_dns_record
  cloud_dns_zone_name         = var.cloud_dns_zone_name

  # --- GKE --- #
  create_gke_cluster                = var.create_gke_cluster
  gke_cluster_name                  = var.gke_cluster_name
  gke_cluster_is_private            = var.gke_cluster_is_private
  gke_control_plane_authorized_cidr = var.gke_control_plane_authorized_cidr
  gke_node_type                     = var.gke_node_type
  gke_node_count                    = var.gke_node_count

  # --- Database --- #
  postgres_db_is_replica        = var.postgres_db_is_replica
  postgres_master_instance_name = var.postgres_master_instance_name
  postgres_insights_config      = var.postgres_insights_config
  postgres_deletion_protection  = var.postgres_deletion_protection
}
```