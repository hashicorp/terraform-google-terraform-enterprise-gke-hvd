# Deployment Customizations

This document describes optional deployment customizations for Terraform Enterprise (TFE) and the corresponding module input variables you can use to tailor the infrastructure to your requirements when the module defaults are not sufficient.

## GKE

By default, this module assumes you are bringing an existing GKE cluster to run TFE.

To have the module create a dedicated GKE cluster instead, set:

```hcl
create_gke_cluster = true
gke_cluster_name   = "<tfe-gke-cluster-name>"
...
...
```

To bring your own GKE cluster (module default):

```hcl
create_gke_cluster = false
```

## IP Address

When `create_tfe_lb_ip` is `true`, this module will automatically create a GCP IP address resource.

### Internal (default)

To create an internal (private) IP address resource, specify the following inputs:

```hcl
create_tfe_lb_ip       = true
tfe_lb_subnet_name     = "<tfe-lb-subnet-name>"
tfe_lb_ip_address      = "<10.0.1.20>"
tfe_lb_ip_address_type = "INTERNAL"
```

The value of `tfe_lb_ip_address` must be an available IP address from the subnet you specified via `tfe_lb_subnet_name`.

### External

If you want to create an external (public) IP address resource to go along with an external load balancer in your Kubernetes service configuration, then you can specify the following inputs:

```hcl
create_tfe_lb_ip       = true
tfe_lb_subnet_name     = null
tfe_lb_ip_address      = null
tfe_lb_ip_address_type = "EXTERNAL"
```

## KMS customer-managed encryption keys (CMEK)

This module supports the ability to pass in a Google customer-managed encryption key (CMEK) for each of the following TFE data storage components:
 - Cloud SQL for PostgreSQL
 - GCS bucket (object storage)
 - Redis

### Cloud SQL

Using a CMEK for Cloud SQL requires providing the **existing** Cloud SQL service agent email for the GCP project so the module can grant the service agent encrypt/decrypt permissions on the KMS key.

```hcl
cloud_sql_service_agent_email = "<service-<PROJECT_ID>@gcp-sa-cloud-sql.iam.gserviceaccount.com>"
postgres_kms_keyring_name     = "<cloud-sql-keyring-name>"
postgres_kms_cmek_name        = "<cloud-sql-crypto-key-name>"
```

The Cloud SQL keyring location must match the location of the Cloud SQL instance (from `var.region`).

### GCS bucket (object storage)

```hcl
gcs_kms_keyring_name = "<gcs-keyring-name>"
gcs_kms_cmek_name    = "<gcs-crypto-key-name>"
```

The GCS keyring location must match the location of the GCS bucket (from `var.gcs_location`).

### Redis

```hcl
redis_kms_keyring_name = "<redis-keyring-name>"
redis_kms_cmek_name    = "<redis-crypto-key-name>"
```

The Redis keyring location must match the location of the Redis instance (from `var.region`).

>📝 Note: the same key may be used for Cloud SQL and Redis since the locations should match.