# Multi-Region Deployment

This module supports deploying TFE in a **primary** region and separately in a **secondary** (disaster recovery) region. The secondary region operates as a **warm-standby** failover target; active-active deployments across regions is not supported.

We recommend separating primary and secondary region deployments into their own Terraform configurations (and state files) so they can be managed independently in the event that an entire region becomes unavailable, which could otherwise result in failed Terraform plans or applies.

## Deployment region breakdown

The following input variables control how the module behaves based on the deployment region (primary or secondary):

- `is_secondary_region_deployment`<br>

  Controls whether the module is deployed into a secondary region and skips resources that should only be created once in the primary region (`false` for **primary**, `true` for **secondary**).

- `postgres_db_is_replica`<br>
   
  Controls whether the Cloud SQL for PostgreSQL instance is provisioned as a primary or replica (`false` for **primary**, `true` for **replica**).

| Component | Resource(s) | Primary only | Both regions | Notes |
|----------|-------------|:------------:|:------------:|-------|
| GKE Cluster (optional) | `google_container_cluster.tfe` |  | ✅ | A separate GKE cluster is created per region (if `create_gke_cluster = true`). |
| Compute IP Address (optional) | `google_compute_address.tfe_lb` |  | ✅ | Load balancer IP is created per region (if `create_tfe_lb_ip = true`). |
| DNS Record (optional) | `google_dns_record_set.tfe` | ✅ |  | Created in the primary region if `create_tfe_cloud_dns_record = true`. Disabled in the secondary region until failover. |
| IAM Service Account | `google_service_account.tfe`<br>`google_project_iam_member.*` | ✅ |  | Created once in the primary region, including all IAM bindings and permissions. IAM resources are **global within a GCP project** and do not need to be duplicated per region. |
| Postgres (Cloud SQL instance) | `google_sql_database_instance.tfe` |  | ✅ | Secondary region instance is initially deployed as a **replica** (`postgres_db_is_replica = true`). |
| Database | `google_sql_database.tfe` | ✅ |  | Created once in the primary region and replicated to the replica instance. |
| Database User | `google_sql_user.tfe` | ✅ |  | Created once in the primary region and replicated to the replica instance. |
| Object Storage (GCS) | `google_storage_bucket.tfe` | ✅ |  | Bucket is created once using a **dual-region** configuration and shared across regions. |
| Memory Store (Redis) | `google_redis_instance.tfe` |  | ✅ | Redis is deployed per region; data is **ephemeral** and not replicated across regions. |

## Data replication

Persistent data must be replicated from the primary region to the secondary region for disaster recovery purposes. This includes the database (Cloud SQL for PostgreSQL) and object storage (GCS bucket). Redis data is **local and ephemeral** and is not replicated across regions.

### Database

Cloud SQL for PostgreSQL replication is configured by deploying the **secondary** region database instance as a **replica** of the primary instance.

```hcl
# primary terraform.tfvars

postgres_db_is_replica = false
```

```hcl
# secondary terraform.tfvars

postgres_db_is_replica        = true
postgres_master_instance_name = "<cloudsql-db-instance-name-primary>"
```

### Object storage

GCS bucket replication is achieved by configuring the bucket with a **dual-region** location type (not a **multi-region** location type) in the **primary** region deployment.

`gcs_location` is always required. Your chosen primary and secondary GCP regions of choice will dictate whether a value is also required for `gcs_custom_dual_region_locations`.

Refer to the [GCS bucket locations](https://docs.cloud.google.com/storage/docs/locations#location-dr) documentation for more details.

#### Example 1 - GCS location as a predefined dual-region pair

If your GCP regions of choice match one of the GCP predefined dual-region pairs listed [here](https://docs.cloud.google.com/storage/docs/locations#predefined), set:

```hcl
# primary terraform.tfvars

gcs_location                     = "<gcs-predefined-dual-region-name>" # e.g., NAM4, EUR4, ASIA1
gcs_custom_dual_region_locations = null
```

In this case, `gcs_custom_dual_region_locations` must be `null`, since the dual-region pairing is already defined by the location code. Google describes this as a _predefined dual-region_.

#### Example 2 - GCS location with custom placement for dual-region pair

If your GCP regions of choice do **not** match any of the predefined dual-region pairs provided by GCP, set:

```hcl
# primary terraform.tfvars

gcs_location                     = "<gcs-multi-region-name>" # e.g., US, EU, ASIA
gcs_custom_dual_region_locations = ["<primary-gcp-region>", "<secondary-gcp-region>"] # e.g., us-east5, us-central1
```

In this case, `gcs_location` specifies the multi-region umbrella and `gcs_custom_dual_region_locations` specifies the two distinct regions that make up the dual-region pairing. **Ensure that you are configuring a valid dual-region pair per the GCP documentation**. Google describes this as a _configurable dual-region_.

## Deployment

To deploy TFE in a primary and secondary (disaster recovery) region, refer to the following example Terraform configurations as a starting point:

- [new-gke-cluster-primary](../examples/new-gke-cluster-primary/)
- [new-gke-cluster-secondary](../examples/new-gke-cluster-secondary/)

>📝 Note: The same concepts apply when using the [byo-gke-cluster](../examples/byo-gke-cluster/) example.

Follow the [Post Steps](../README.md#post-steps) for both region deployments.

While updating/customizing your Helm overrides values in the secondary region deployment, set `replicaCount: 0` before running the Helm install. TFE cannot successfully install without a writable database. Since the secondary region database is deployed as a replica, no TFE application pods should be started until failover. As a result, **stop after the Helm install step** for the secondary region deployment. The `replicaCount` should not be scaled up until a failover.

## Failover steps

1. **Promote the secondary region database**<br>
   
   Promote the Cloud SQL for PostgreSQL **read replica** in the secondary region to a standalone primary (read/write) instance. This can be performed using the `gcloud` CLI, the GCP API, or the GCP Console.

   Once the read replica has been promoted, update the following input values in your Terraform configuration to reflect the new standalone primary role:

   ```hcl
   # secondary terraform.tfvars

   postgres_db_is_replica        = false # previously true
   postgres_master_instance_name = null # previously "<primary-tfe-cloud-sql-instance-name>"
   ```
   
   Run `terraform apply` against your secondary region Terraform configuration. Applying this change updates Terraform’s view of the instance so it is managed as a standalone primary, including applying the primary region backup configuration and maintenance window settings defined by the module.

   >Note: You may wait to run `terraform apply` until after step 2 in order to apply both changes at once, if applicable.

2. **Update DNS to point to the secondary region**<br>
   
   Update the TFE DNS record so that it resolves to the **secondary region load balancer IP address**.

   You may perform this step either using this module (if using Google Cloud DNS), a separate Terraform configuration, or outside of Terraform, depending on how you prefer to manage DNS during failover.

   If managing DNS using this module, set:

   ```hcl
   # secondary terraform.tfvars
   
   create_tfe_cloud_dns_record = true # previously false
   ```

   Run `terraform apply` against your secondary region Terraform configuration. Applying this change will update the existing DNS record to reference the secondary region load balancer IP address.

3. **Scale the TFE application**<br>

   Update the value of `replicaCount` from `0` to the desired number of replicas in your **secondary region Helm overrides**, then run `helm upgrade` (with the appropriate arguments) to apply the change.

4. **Verify the deployment**<br>

   Verify that the TFE application is healthy by checking pod logs, reviewing health checks, and confirming access through the TFE UI.

## Post-failover normalization

**Do not perform these steps until the primary region has fully recovered and is confirmed to be reachable and healthy.**

1. **Prevent DNS reversion to the primary region**

   Since the secondary region deployment is now the active TFE instance, ensure that the TFE DNS record is not pointed back to the primary region load balancer prematurely.

   This step is only required if DNS management was enabled in the original primary region deployment (`create_tfe_cloud_dns_record = true`). If that was the case, then toggle it off in the primary region Terraform configuration:

   ```hcl
   # primary terraform.tfvars

   create_tfe_cloud_dns_record = false # previously true
   ```

   This ensures that subsequent Terraform runs against the primary region (required for database normalization) do not attempt to reassert the primary region load balancer IP while the secondary region remains active.

   _If DNS was not managed by this module in the primary region, no action is required for this step._

2. **Re-establish database replication to the primary region**

   After failover, both Cloud SQL database instances exist as standalone (primary) instances. To normalize the deployment, replication must first be re-established **in the opposite direction**, from the secondary region back to the primary region.

   Update the Terraform configuration for the primary region deployment as follows:

   ```hcl
   # primary terraform.tfvars

   postgres_db_is_replica        = true # previously false
   postgres_master_instance_name = "<secondary-tfe-cloud-sql-instance-name>" # previously null
   ```

   Run `terraform apply` against the primary region Terraform configuration. Applying this change will **destroy and recreate** the Cloud SQL instance in the primary region as a read replica of the secondary region Cloud SQL instance, restoring the replication in the opposite direction.

   ⚠️ **Important:** 
   Because the Cloud SQL instance is recreated, its IP address is likely to change. As a result, a new value must be set in the **primary region Helm overrides** for `TFE_DATABASE_HOST`. This value can be obtained from the Terraform output `tfe_database_host`.

3. **Fail back to the primary region (service-impacting)**

   This step transitions the active Terraform Enterprise deployment back to the primary region. It is service-impacting and should only be performed during a planned maintenance window.
   
   **Prerequisites:**
   - Database replication from the secondary region to the primary region is fully synchronized
   - The secondary region remains the active TFE deployment
   - The primary region database is a read replica
   - Replication direction is secondary → primary
   
   During this step, the active TFE instance in the secondary region will be taken out of service, and the primary region will be restored as the active deployment.

**3.1 Take the secondary region TFE deployment out of service**

   Before modifying database replication roles, the active Terraform Enterprise instance in the secondary region must be taken out of service.

   Shut down the TFE application in the secondary region by scaling the deployment to zero replicas in your **secondary region Helm overrides** and running `helm upgrade` (with the appropriate arguments).

   At the end of this step:

   - No TFE application instances are actively serving traffic
   - Database replication remains intact (secondary → primary)
   - DNS should still point to the secondary region (or be temporarily disabled)

   ⚠️ Important:
   Do not promote the primary region database or modify replication roles while the TFE application is actively running.

**3.2 Promote the primary region database**

   Promote the Cloud SQL for PostgreSQL **read replica** in the primary region to a standalone primary (read/write) instance. This can be performed using the `gcloud` CLI, the GCP API, or the GCP Console.

   Once the read replica has been promoted, update the following input values in your **primary region** Terraform configuration to reflect the new standalone primary role:

   ```hcl
   # primary terraform.tfvars

   postgres_db_is_replica        = false # previously true
   postgres_master_instance_name = null # previously "<secondary-tfe-cloud-sql-instance-name>"
   ```
   
   Run `terraform apply` against your primary region Terraform configuration.

**3.3 Recreate the secondary region database as a replica**
   
   Re-establish database replication in the original direction by recreating the secondary region Cloud SQL instance as a **read replica of the primary region database**.

   ```hcl
   # secondary terraform.tfvars

   postgres_db_is_replica        = true # previously false
   postgres_master_instance_name = "<primary-tfe-cloud-sql-instance-name>" # previously null
   ```

   Run `terraform apply` against your secondary region Terraform configuration. Applying this change will **destroy and recreate** the Cloud SQL instance in the secondary region as a read replica of the primary region database.
   
   ⚠️ **Important:** 
   Because the Cloud SQL instance is recreated, its IP address is likely to change. As a result, a new value must be set in the **secondary region Helm overrides** for `TFE_DATABASE_HOST`. This value can be obtained from the Terraform output `tfe_database_host`.

   After updating the Helm value, run `helm upgrade` (with the appropriate arguments) so the secondary region TFE configuration references the correct `TFE_DATABASE_HOST`.

**3.4 Update DNS to point back to the primary region**

   Update the TFE DNS record so that it resolves to the primary region load balancer IP address.

   You may perform this step using this module (if using Google Cloud DNS), a separate Terraform configuration, or outside of Terraform, depending on how you prefer to manage DNS during failback.

   If managing DNS using this module, re-enable DNS management in the primary region deployment by setting:

   ```hcl
   # primary terraform.tfvars

   create_tfe_cloud_dns_record = true # previously false
   ```
   
   Run `terraform apply` against your primary region Terraform configuration. Applying this change will update the DNS record to reference the primary region load balancer IP address.

**3.5 Bring up the TFE application in the primary region**

   Ensure you have the correct value of `TFE_DATABASE_HOST` in your **primary region Helm overrides**. This value was obtained from the Terraform output `tfe_database_host` from step 2.
   
   Update the value of `replicaCount` from `0` to the desired number of replicas in your **primary region Helm overrides**, then run `helm upgrade` (with the appropriate arguments) to apply the change and bring the TFE application back online in the primary region.