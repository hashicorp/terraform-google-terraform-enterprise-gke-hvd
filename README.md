# Terraform Enterprise HVD on GCP GKE

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise (TFE) on Google Kubernetes Engine (GKE). This module supports bringing your own GKE cluster, or optionally creating a new GKE cluster dedicated to running TFE. This module does not use the Kubernetes or Helm Terraform providers, but rather includes [Post Steps](#post-steps) for the application layer portion of the deployment leveraging the `kubectl` and `helm` CLIs.

## Prerequisites

### General

- TFE license file (_e.g._, `terraform.hclic`)
- Terraform CLI (version `>= 1.9`) installed on workstation
- General understanding of how to use Terraform (Community Edition)
- General understaning of how to use Google Cloud Platform (GCP)
- General understanding of how to use Kubernetes and Helm
- `gcloud` CLI installed on workstation
- `kubectl` CLI and `helm` CLI installed on workstation
- `git` CLI and Visual Studio Code code editor installed on worksation are strongly recommended
- GCP project that TFE will be deployed in with permissions to provision these [resources](#resources) via Terraform CLI
- (Optional) GCS bucket for [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) that will be used to manage the Terraform state of this TFE deployment (out-of-band from the TFE application infrastructure) via Terraform CLI (Community Edition)

### Networking

- VPC network that TFE will be deployed in
  - GKE cluster must be deployed in the same VPC network as CloudSQL for PostgreSQL database instance and Memorystore for Redis instance
- **Private Service Access (PSA)** configured in VPC to enable private connectivity from GKE worker nodes to Cloud SQL for PostgreSQL database instance and Memorystore for Redis instance
- Subnet for GKE cluster (if you plan to use this module to create your GKE cluster for TFE rather than bring your own GKE cluster)
  - It is strongly recommended that this subnet has **Private Google Access** enabled to allow private access from the GKE cluster to the Google Cloud Storage (GCS) bucket.
- Static IP address for TFE load balancer (to be used by either a Kubernetes `Service` of type `LoadBalancer` or an ingress controller)
- Chosen fully qualified domain name (FQDN) for TFE instance (_e.g._, `tfe-prod.gcp.example.com`)

#### Firewall rules / network traffic requirements

- Allow `TCP:443` ingress to TFE load balancer from CIDR ranges of TFE users/clients, VCS provider, and any other external systems that needs to access the TFE UI or API
- Allow `TCP:8201` between TFE pods (for TFE embedded Vault internal cluster communication) - **typically handled automatically/natively by GKE and does not require a custom firewall rule**
- Allow `TCP:443` egress to Terraform endpoints listed [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress) from TFE pods
- If your GKE cluster is **private**, your clients/workstations must be able to reach the GKE control plane via `kubectl` and `helm`
- Review the [TFE ingress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#ingress)
- Review the [TFE egress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress)

### TLS certificates

- TLS certificate (_e.g._ `cert.pem`) and private key (_e.g._ `privkey.pem`) that matches your chosen fully qualified domain name (FQDN) for TFE
  - TLS certificate and private key must be in PEM format
  - Private key must **not** be password protected
- TLS certificate authority (CA) bundle (_e.g._ `ca_bundle.pem`) corresponding with the CA that issues your TFE TLS certificates
  - CA bundle must be in PEM format
  - You may include additional certificate chains corresponding to external systems that TFE will make outbound connections to (_e.g._, your self-hosted VCS, if its certificate was issued by a different CA than the issuer of your TFE TLS certificate)

### Secret management

Google Secret Manager secrets:

- PostgreSQL database password secret

### Compute (optional)

If you plan to create a new GKE cluster using this module, then there is no GKE prereq. Otherwise:

 - GKE cluster
 - (Recommended) Workload identity enabled on GKE cluster (`workload_pool = "<PROJECT_ID>.svc.id.goog"`)
 - GKE node pool for TFE application (control plane)

---

## Usage

1. Create/configure/validate the applicable [prerequisites](#prerequisites).

2. Nested within the [examples](./examples/) directory are subdirectories that contain ready-made Terraform configurations of example scenarios for how to deploy this module. To get started, choose an example scenario. If you are starting without an existing GKE cluster, then you should select the [new-gke](examples/new-gke) example scenario.

3. Copy all of the Terraform files from your example scenario of choice into a new destination directory to create the Terraform configuration that will manage your TFE deployment. If you are not sure where to create this new directory, it is common for users to create an `environments/` directory at the root of this repo (once you have cloned it down locally), and then a subdirectory for each TFE instance deployment. For example:

    ```pre
    .
    └── environments
        ├── production
        │   ├── backend.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── terraform.tfvars
        │   └── variables.tf
        └── sandbox
            ├── backend.tf
            ├── main.tf
            ├── outputs.tf
            ├── terraform.tfvars
            └── variables.tf
    ```

    >📝 Note: In this example, the user will have two separate TFE deployments; one for their `sandbox` environment, and one for their `production` environment. This is recommended, but not required.

4. (Optional) Uncomment and update the [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) configuration provided in the `backend.tf` file with your own custom values. While this step is highly recommended, it is technically not required to use a remote backend config for your TFE deployment (if you are in a sandbox environment, for example).

5. Populate your own custom values into the `terraform.tfvars.example` file that was provided (in particular, values enclosed in the `<>` characters). Then, remove the `.example` file extension such that the file is now named `terraform.tfvars`.

6. Navigate to the directory of the newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

**At this point, the Terraform-managed infrastructure resources for TFE have been created.**

The next phase of the deployment is the application layer (referred to as the **Post Steps**). This phase involves interacting with your GKE cluster using `kubectl` and installing the TFE application using `helm`. The steps are documented using these CLI tools as a baseline; equivalent Kubernetes tooling or workflows may be used as appropriate.

## Post steps

7. Authenticate to your GKE cluster:

   ```shell
   gcloud auth login
   gcloud config set project <PROJECT_ID>
   gcloud container clusters get-credentials <GKE_CLUSTER_NAME> --region <REGION>
   ```

8. Create the Kubernetes namespace for TFE:

   ```shell
   kubectl create namespace tfe
   ```
   
   >📝 Note: You may name it something different than `tfe` if you prefer. If you do name it differently, be sure to update your value of the `tfe_kube_namespace` and `tfe_kube_svc_account` input variables accordingly (the Helm chart will automatically create a Kubernetes service account for TFE based on the name of the namespace).

9. Create the required secrets for your TFE deployment within your new Kubernetes namespace for TFE. There are several ways to do this, whether it be from the CLI via `kubectl`, or another method involving a third-party secrets helper/tool. 

    See the [Kubernetes-Secrets](./docs/kubernetes-secrets.md) doc for details on the required secrets and how to create them.

10. This Terraform module will automatically generate a Helm overrides file within your Terraform working directory named `./helm/module_generated_helm_overrides.yaml`. This Helm overrides file contains values interpolated from some of the infrastructure resources that were created by Terraform in step 6.

    Within the Helm overrides file, update or validate the values for the remaining settings that are enclosed in the `<>` characters. You may also add any additional configuration settings into your Helm overrides file at this time (see the [Helm-Overrides](./docs/helm-overrides.md) doc for more details).

11. Now that you have customized your `module_generated_helm_overrides.yaml` file, rename it to something more applicable to your deployment, such as `prod_tfe_overrides_primary.yaml` (or whatever you prefer). 

    Then, within your `terraform.tfvars` file, set the value of `create_helm_overrides_file` to `false`, as we no longer need the Terraform module to manage this file or generate a new one on a subsequent Terraform run.

12. Add the HashiCorp Helm registry:

    ```shell
    helm repo add hashicorp https://helm.releases.hashicorp.com
    ```

    >📝 Note: If you have already added the `hashicorp` Helm repository, you should run `helm repo update hashicorp` to ensure that you have the latest version.


13. Install the TFE application via `helm`:

    ```shell
    helm install terraform-enterprise hashicorp/terraform-enterprise --namespace <TFE_NAMESPACE> --values <TFE_OVERRIDES_FILE>
    ```

14. Verify the TFE pod(s) are starting successfully:

    View the events within the namespace:

    ```shell
    kubectl get events --namespace <TFE_NAMESPACE>
    ```

    View the pod(s) within the namespace:

    ```shell
    kubectl get pods --namespace <TFE_NAMESPACE>
    ```

    View the logs from the pod:

    ```shell
    kubectl logs <TFE_POD_NAME> --namespace <TFE_NAMESPACE> -f
    ```

15. If you did not create a DNS record during your Terraform deployment in the previous section (via the boolean input `create_tfe_cloud_dns_record`), then create a DNS record for your TFE FQDN that resolves to your TFE load balancer, depending on how the load balancer was configured during your TFE deployment:

    - If you are using a Kubernetes service of type `LoadBalancer` (what the module-generated Helm overrides defaults to), the DNS record should resolve to the static IP address of your TFE load balancer:

      ```shell
      kubectl get services --namespace <TFE_NAMESPACE>
      ```

    - If you are using a custom Kubernetes ingress (meaning you customized your Helm overrides in step 10), the DNS record should resolve to the IP address of your ingress controller load balancer:

      ```shell
      kubectl get ingress <INGRESS_NAME> --namespace <INGRESS_NAMESPACE>
      ```

16. Verify the TFE application is ready:

    ```shell
    curl https://<TFE_FQDN>/_health_check
    ```

17. Follow the remaining steps [here](https://developer.hashicorp.com/terraform/enterprise/deploy/kubernetes#create-initial-admin-user) to finish the installation setup, which involves **creating the initial admin user**.

## Docs

Below are links to various docs related to the customization and management of your TFE deployment:

 - [TFE Deployment Customizations](./docs/deployment-customizations.md)
 - [TFE Helm Overrides](./docs/helm-overrides.md)
 - [TFE Version Upgrades](./docs/tfe-version-upgrades.md)
 - [TFE TLS Certificate Rotation](./docs/tfe-cert-rotation.md)
 - [TFE Configuration Settings](./docs/tfe-config-settings.md)
 - [TFE Kubernetes Secrets](./docs/kubernetes-secrets.md)
 - [TFE Multi-Region Deployment](./docs/multi-region-deployment.md)

Please note that there is no official Service Level Agreement (SLA) for support of this software as a HashiCorp customer. This software falls under the definition of Community Software/Versions in your Agreement. We appreciate your understanding and collaboration in improving our open source projects.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 7.14 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 7.14 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.5.1 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.2 |

## Resources

| Name | Type |
|------|------|
| [google_compute_address.tfe_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_container_cluster.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_dns_record_set.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_kms_crypto_key_iam_member.cloud_sql_sa_postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.gcs_sa_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.redis_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_project_iam_member.gke_artifact_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_default_node_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_metric_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_object_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_stackdriver_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.tfe_cloudsql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.tfe_cloudsql_instance_user](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_redis_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance) | resource |
| [google_service_account.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_member.tfe_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |
| [google_service_account_key.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_key) | resource |
| [google_sql_database.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) | resource |
| [google_sql_database_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_storage_bucket.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_member.tfe_gcs_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.tfe_gcs_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [local_file.helm_values_values](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_id.gcs_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.postgres_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_compute_network.vpc](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network) | data source |
| [google_compute_subnetwork.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_subnetwork.tfe_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_subnetwork) | data source |
| [google_compute_zones.up](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_zones) | data source |
| [google_dns_managed_zone.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/dns_managed_zone) | data source |
| [google_kms_crypto_key.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_crypto_key.redis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_crypto_key.tfe_gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_crypto_key) | data source |
| [google_kms_key_ring.postgres](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_kms_key_ring.redis](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_kms_key_ring.tfe_gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/kms_key_ring) | data source |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_secret_manager_secret_version.tfe_database_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/secret_manager_secret_version) | data source |
| [google_service_account.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account) | data source |
| [google_storage_project_service_account.gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Prefix used to name all GCP resources uniquely. It is most common to use either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name here. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of GCP project to deploy TFE in. | `string` | n/a | yes |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name (FQDN) of TFE instance. This name should eventually resolve to the TFE load balancer DNS name or IP address and will be what clients use to access TFE. | `string` | n/a | yes |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of existing VPC network to create resources in. | `string` | n/a | yes |
| <a name="input_cloud_dns_zone_name"></a> [cloud\_dns\_zone\_name](#input\_cloud\_dns\_zone\_name) | Name of Google Cloud DNS managed zone to create TFE DNS record in. Only valid when `create_cloud_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_cloud_sql_service_agent_email"></a> [cloud\_sql\_service\_agent\_email](#input\_cloud\_sql\_service\_agent\_email) | Email address of the Google-managed Cloud SQL service agent (service account) for this GCP project (usually service-<PROJECT\_ID>@gcp-sa-cloud-sql.iam.gserviceaccount.com). Only required when using a customer-managed encryption key (CMEK) to grant the service agent encrypt/decrypt permissions. | `string` | `null` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Common labels to apply to all GCP resources that support labels. | `map(string)` | `{}` | no |
| <a name="input_create_gke_cluster"></a> [create\_gke\_cluster](#input\_create\_gke\_cluster) | Boolean to create a GKE cluster. | `bool` | `false` | no |
| <a name="input_create_helm_overrides_file"></a> [create\_helm\_overrides\_file](#input\_create\_helm\_overrides\_file) | Boolean to generate a YAML file from template with Helm overrides values for your TFE deployment. Set this to `false` after your initial TFE deployment is complete, as we no longer want the Terraform module to manage it (since you will be customizing it further). | `bool` | `true` | no |
| <a name="input_create_tfe_cloud_dns_record"></a> [create\_tfe\_cloud\_dns\_record](#input\_create\_tfe\_cloud\_dns\_record) | Boolean to create Google Cloud DNS record for TFE using the value of `tfe_fqdn` for the record name. | `bool` | `false` | no |
| <a name="input_create_tfe_lb_ip"></a> [create\_tfe\_lb\_ip](#input\_create\_tfe\_lb\_ip) | Boolean to create a static IP address for TFE load balancer (load balancer is created/managed by Helm/Kubernetes). | `bool` | `true` | no |
| <a name="input_enable_gke_workload_identity"></a> [enable\_gke\_workload\_identity](#input\_enable\_gke\_workload\_identity) | Boolean to enable GCP workload identity with GKE cluster. | `bool` | `true` | no |
| <a name="input_enable_passwordless_iam_db_auth"></a> [enable\_passwordless\_iam\_db\_auth](#input\_enable\_passwordless\_iam\_db\_auth) | Whether to enable passwordless IAM authentication to Cloud SQL for PostreSQL database instance. | `bool` | `false` | no |
| <a name="input_gcs_custom_dual_region_locations"></a> [gcs\_custom\_dual\_region\_locations](#input\_gcs\_custom\_dual\_region\_locations) | Optional list of exactly two GCS region codes (e.g., ["US-EAST1", "US-CENTRAL1"]) to use dual-region custom placement. When set, `gcs_location` must be the corresponding multi-region (US, EU, or ASIA), and `gcs_location` must not be a predefined dual-region code (NAM4, EUR4, ASIA1). | `list(string)` | `null` | no |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Boolean indicating whether to allow force destroying the TFE GCS bucket. GCS bucket can be destroyed if it is not empty when `true`. | `bool` | `false` | no |
| <a name="input_gcs_kms_cmek_name"></a> [gcs\_kms\_cmek\_name](#input\_gcs\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. | `string` | `null` | no |
| <a name="input_gcs_kms_keyring_name"></a> [gcs\_kms\_keyring\_name](#input\_gcs\_kms\_keyring\_name) | Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. Geographic location (region) of the key ring must match the location of the TFE GCS bucket. | `string` | `null` | no |
| <a name="input_gcs_location"></a> [gcs\_location](#input\_gcs\_location) | Location of TFE GCS bucket to create. Supports multi-region (US, EU, ASIA) and predefined dual-region (NAM4, EUR4, ASIA1). | `string` | `"US"` | no |
| <a name="input_gcs_public_access_prevention"></a> [gcs\_public\_access\_prevention](#input\_gcs\_public\_access\_prevention) | Prevent public access to TFE GCS bucket. | `string` | `"enforced"` | no |
| <a name="input_gcs_rpo"></a> [gcs\_rpo](#input\_gcs\_rpo) | The recovery point objective for cross-region replication of the GCS bucket. | `string` | `"DEFAULT"` | no |
| <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class) | Storage class of TFE GCS bucket. | `string` | `"STANDARD"` | no |
| <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access) | Boolean to enable uniform bucket level access on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled) | Boolean to enable versioning on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_gke_cluster_is_private"></a> [gke\_cluster\_is\_private](#input\_gke\_cluster\_is\_private) | Boolean indicating if GKE network access is private cluster. | `bool` | `true` | no |
| <a name="input_gke_cluster_name"></a> [gke\_cluster\_name](#input\_gke\_cluster\_name) | Name of GKE cluster to create. | `string` | `"tfe-gke-cluster"` | no |
| <a name="input_gke_cluster_node_locations"></a> [gke\_cluster\_node\_locations](#input\_gke\_cluster\_node\_locations) | List of zones in which node pool nodes should be located. | `list(string)` | `null` | no |
| <a name="input_gke_control_plane_authorized_cidr"></a> [gke\_control\_plane\_authorized\_cidr](#input\_gke\_control\_plane\_authorized\_cidr) | CIDR block allowed to access GKE control plane. | `string` | `null` | no |
| <a name="input_gke_control_plane_cidr"></a> [gke\_control\_plane\_cidr](#input\_gke\_control\_plane\_cidr) | Control plane IP range of private GKE cluster. Must not overlap with any subnet in GKE cluster's VPC. | `string` | `"10.0.10.0/28"` | no |
| <a name="input_gke_deletion_protection"></a> [gke\_deletion\_protection](#input\_gke\_deletion\_protection) | Boolean to enable deletion protection on GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_enable_private_endpoint"></a> [gke\_enable\_private\_endpoint](#input\_gke\_enable\_private\_endpoint) | Boolean to enable private endpoint on GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_http_load_balancing_disabled"></a> [gke\_http\_load\_balancing\_disabled](#input\_gke\_http\_load\_balancing\_disabled) | Boolean to enable HTTP load balancing on GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_l4_ilb_subsetting_enabled"></a> [gke\_l4\_ilb\_subsetting\_enabled](#input\_gke\_l4\_ilb\_subsetting\_enabled) | Boolean to enable layer 4 ILB subsetting on GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_node_count"></a> [gke\_node\_count](#input\_gke\_node\_count) | Number of GKE nodes per zone in TFE node pool. | `number` | `1` | no |
| <a name="input_gke_node_disk_size_gb"></a> [gke\_node\_disk\_size\_gb](#input\_gke\_node\_disk\_size\_gb) | Boot disk size in gigabytes (GB) for GKE nodes in TFE node pool. | `number` | `100` | no |
| <a name="input_gke_node_disk_type"></a> [gke\_node\_disk\_type](#input\_gke\_node\_disk\_type) | Type of disk for GKE nodes in TFE node pool. | `string` | `"hyperdisk-balanced"` | no |
| <a name="input_gke_node_pool_name"></a> [gke\_node\_pool\_name](#input\_gke\_node\_pool\_name) | Name of TFE node pool to create in GKE cluster. | `string` | `"tfe-gke-node-pool"` | no |
| <a name="input_gke_node_type"></a> [gke\_node\_type](#input\_gke\_node\_type) | Size/machine type of GKE nodes in TFE node pool. | `string` | `"n4-standard-8"` | no |
| <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel) | The channel to use for how frequent Kubernetes updates and features are received. | `string` | `"REGULAR"` | no |
| <a name="input_gke_remove_default_node_pool"></a> [gke\_remove\_default\_node\_pool](#input\_gke\_remove\_default\_node\_pool) | Boolean to remove the default node pool in GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_subnet_name"></a> [gke\_subnet\_name](#input\_gke\_subnet\_name) | Name or self\_link to existing VPC subnetwork to create GKE cluster in. | `string` | `null` | no |
| <a name="input_is_secondary_region_deployment"></a> [is\_secondary\_region\_deployment](#input\_is\_secondary\_region\_deployment) | Whether this deployment represents the secondary (DR) region (TFE warm-standby instance). | `bool` | `false` | no |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL for PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_config"></a> [postgres\_backup\_config](#input\_postgres\_backup\_config) | Backup configuration for Cloud SQL for PostgreSQL instance. | <pre>object({<br/>    enabled                        = bool   # Enable automated backups for the Cloud SQL for PostgreSQL instance<br/>    start_time                     = string # Daily backup start time in HH:MM format<br/>    point_in_time_recovery_enabled = bool   # Enable point-in-time recovery (PITR)<br/>    transaction_log_retention_days = number # Number of days to retain transaction logs for PITR<br/>    retained_backups               = number # Number of daily backups to retain<br/>  })</pre> | <pre>{<br/>  "enabled": true,<br/>  "point_in_time_recovery_enabled": true,<br/>  "retained_backups": 30,<br/>  "start_time": "00:00",<br/>  "transaction_log_retention_days": 14<br/>}</pre> | no |
| <a name="input_postgres_db_is_replica"></a> [postgres\_db\_is\_replica](#input\_postgres\_db\_is\_replica) | Whether the Cloud SQL for PostreSQL database instance in this deployment is a read replica. | `bool` | `false` | no |
| <a name="input_postgres_deletion_protection"></a> [postgres\_deletion\_protection](#input\_postgres\_deletion\_protection) | Whether to prevent the Cloud SQL for PostgreSQL instance from being destroyed. | `bool` | `true` | no |
| <a name="input_postgres_disk_autoresize"></a> [postgres\_disk\_autoresize](#input\_postgres\_disk\_autoresize) | Whether to enable autoresize on the Cloud SQL for PostgreSQL disk. | `bool` | `true` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `100` | no |
| <a name="input_postgres_disk_type"></a> [postgres\_disk\_type](#input\_postgres\_disk\_type) | Type of data disk for Cloud SQL for PostgreSQL instance. | `string` | `"PD_SSD"` | no |
| <a name="input_postgres_edition"></a> [postgres\_edition](#input\_postgres\_edition) | Cloud SQL for PostgreSQL edition (ENTERPRISE or ENTERPRISE\_PLUS). | `string` | `"ENTERPRISE_PLUS"` | no |
| <a name="input_postgres_insights_config"></a> [postgres\_insights\_config](#input\_postgres\_insights\_config) | Configuration settings for Cloud SQL for PostgreSQL insights. | <pre>object({<br/>    query_insights_enabled  = bool<br/>    query_plans_per_minute  = number<br/>    query_string_length     = number<br/>    record_application_tags = bool<br/>    record_client_address   = bool<br/>  })</pre> | <pre>{<br/>  "query_insights_enabled": false,<br/>  "query_plans_per_minute": 5,<br/>  "query_string_length": 1024,<br/>  "record_application_tags": false,<br/>  "record_client_address": false<br/>}</pre> | no |
| <a name="input_postgres_kms_cmek_name"></a> [postgres\_kms\_cmek\_name](#input\_postgres\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_kms_keyring_name"></a> [postgres\_kms\_keyring\_name](#input\_postgres\_kms\_keyring\_name) | Name of Cloud KMS Key Ring that contains KMS key specified in `postgres_kms_cmek_name`. Geographic location (region) of key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL for PostgreSQL instance. | `string` | `"db-perf-optimized-N-8"` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Optional maintenance window settings for the Cloud SQL for PostgreSQL instance. | <pre>object({<br/>    day          = number<br/>    hour         = number<br/>    update_track = string<br/>  })</pre> | <pre>{<br/>  "day": 7,<br/>  "hour": 0,<br/>  "update_track": "stable"<br/>}</pre> | no |
| <a name="input_postgres_master_instance_name"></a> [postgres\_master\_instance\_name](#input\_postgres\_master\_instance\_name) | Name of TFE Cloud SQL for PostgreSQL database instance deployed in primary region. Used to create a read replica in the secondary region. Only set when `postgres_db_is_replica` is `true`. | `string` | `null` | no |
| <a name="input_postgres_ssl_mode"></a> [postgres\_ssl\_mode](#input\_postgres\_ssl\_mode) | Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance. | `string` | `"ENCRYPTED_ONLY"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version to use. | `string` | `"POSTGRES_16"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | ID of GCP project to deploy TFE in. | `string` | n/a | yes |
| <a name="input_redis_auth_enabled"></a> [redis\_auth\_enabled](#input\_redis\_auth\_enabled) | Boolean to enable authentication on Redis instance. | `bool` | `true` | no |
| <a name="input_redis_connect_mode"></a> [redis\_connect\_mode](#input\_redis\_connect\_mode) | Network connection mode for Redis instance. | `string` | `"PRIVATE_SERVICE_ACCESS"` | no |
| <a name="input_redis_kms_cmek_name"></a> [redis\_kms\_cmek\_name](#input\_redis\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE Redis instance. | `string` | `null` | no |
| <a name="input_redis_kms_keyring_name"></a> [redis\_kms\_keyring\_name](#input\_redis\_kms\_keyring\_name) | Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE Redis instance. Geographic location (region) of key ring must match the location of the TFE Redis instance. | `string` | `null` | no |
| <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb) | The size of the Redis instance in GiB. | `number` | `6` | no |
| <a name="input_redis_tier"></a> [redis\_tier](#input\_redis\_tier) | The service tier of the Redis instance. Defaults to `STANDARD_HA` for high availability. | `string` | `"STANDARD_HA"` | no |
| <a name="input_redis_transit_encryption_mode"></a> [redis\_transit\_encryption\_mode](#input\_redis\_transit\_encryption\_mode) | Determines transit encryption (TLS) mode for Redis instance. | `string` | `"DISABLED"` | no |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | The version of Redis software. | `string` | `"REDIS_7_2"` | no |
| <a name="input_tfe_cloud_dns_record_ip_address"></a> [tfe\_cloud\_dns\_record\_ip\_address](#input\_tfe\_cloud\_dns\_record\_ip\_address) | IP address of DNS record for TFE. Only valid when `create_cloud_dns_record` is `true` and `create_tfe_lb_ip` is `false`. | `string` | `null` | no |
| <a name="input_tfe_database_name"></a> [tfe\_database\_name](#input\_tfe\_database\_name) | Name of TFE PostgreSQL database to create. | `string` | `"tfe"` | no |
| <a name="input_tfe_database_parameters"></a> [tfe\_database\_parameters](#input\_tfe\_database\_parameters) | Additional parameters to pass into the TFE database settings for the PostgreSQL connection URI. | `string` | `"sslmode=require"` | no |
| <a name="input_tfe_database_password_secret_version"></a> [tfe\_database\_password\_secret\_version](#input\_tfe\_database\_password\_secret\_version) | Name of Google Secret Manager secret version for the PostgreSQL password. Only used for primary region deployments when `enable_passwordless_iam_db_auth` is false. | `string` | `null` | no |
| <a name="input_tfe_database_user"></a> [tfe\_database\_user](#input\_tfe\_database\_user) | Name of TFE PostgreSQL database user to create. Only valid for primary region deployments when password auth is used. | `string` | `null` | no |
| <a name="input_tfe_gcp_svc_account_name"></a> [tfe\_gcp\_svc\_account\_name](#input\_tfe\_gcp\_svc\_account\_name) | Name of GCP custom service account for TFE. Service account is used for GKE workload identity, GCS bucket permissions, and optional database authentication. | `string` | `"tfe-gcp-sa"` | no |
| <a name="input_tfe_gcs_bucket_name"></a> [tfe\_gcs\_bucket\_name](#input\_tfe\_gcs\_bucket\_name) | Name of TFE GCS bucket that was created in the primary region TFE deployment. Only set when `is_secondary_region_deployment` is `true`. | `string` | `null` | no |
| <a name="input_tfe_kube_namespace"></a> [tfe\_kube\_namespace](#input\_tfe\_kube\_namespace) | Name of Kubernetes namespace for TFE (created in post-deployment steps). Used to configure GCP workload identity with GKE. | `string` | `"tfe"` | no |
| <a name="input_tfe_kube_svc_account"></a> [tfe\_kube\_svc\_account](#input\_tfe\_kube\_svc\_account) | Name of Kubernetes Service Account for TFE (created by Helm chart). Used to configure GCP workload identity with GKE. | `string` | `"tfe"` | no |
| <a name="input_tfe_lb_ip_address"></a> [tfe\_lb\_ip\_address](#input\_tfe\_lb\_ip\_address) | IP address to assign to TFE load balancer. Must be a valid IP address from `tfe_lb_subnet_name` when `tfe_lb_ip_address_type` is `INTERNAL`. | `string` | `null` | no |
| <a name="input_tfe_lb_ip_address_type"></a> [tfe\_lb\_ip\_address\_type](#input\_tfe\_lb\_ip\_address\_type) | Type of IP address to assign to TFE load balancer. Valid values are 'INTERNAL' or 'EXTERNAL'. | `string` | `"INTERNAL"` | no |
| <a name="input_tfe_lb_subnet_name"></a> [tfe\_lb\_subnet\_name](#input\_tfe\_lb\_subnet\_name) | Name or self\_link to existing VPC subnetwork to create TFE internal load balancer IP address in. | `string` | `null` | no |
| <a name="input_vpc_project_id"></a> [vpc\_project\_id](#input\_vpc\_project\_id) | ID of GCP Project where the existing VPC resides if it is different than the default project. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gke_cluster_name"></a> [gke\_cluster\_name](#output\_gke\_cluster\_name) | Name of TFE GKE cluster. |
| <a name="output_postgres_db_instance_id"></a> [postgres\_db\_instance\_id](#output\_postgres\_db\_instance\_id) | Name (ID) of TFE Cloud SQL for PostgreSQL database instance in this region. |
| <a name="output_redis_server_ca_certs"></a> [redis\_server\_ca\_certs](#output\_redis\_server\_ca\_certs) | CA certificate of TFE Redis instance. Add this to your TFE CA bundle. |
| <a name="output_tfe_database_host"></a> [tfe\_database\_host](#output\_tfe\_database\_host) | IP address and port of TFE Cloud SQL for PostgreSQL database instance. |
| <a name="output_tfe_database_name"></a> [tfe\_database\_name](#output\_tfe\_database\_name) | TFE PostgreSQL database name. |
| <a name="output_tfe_database_password"></a> [tfe\_database\_password](#output\_tfe\_database\_password) | TFE PostgreSQL database password. |
| <a name="output_tfe_database_password_base64"></a> [tfe\_database\_password\_base64](#output\_tfe\_database\_password\_base64) | Base64-encoded TFE PostgreSQL database password. |
| <a name="output_tfe_database_user"></a> [tfe\_database\_user](#output\_tfe\_database\_user) | TFE PostgreSQL database username. |
| <a name="output_tfe_lb_ip_address"></a> [tfe\_lb\_ip\_address](#output\_tfe\_lb\_ip\_address) | IP address of TFE load balancer. |
| <a name="output_tfe_lb_ip_address_name"></a> [tfe\_lb\_ip\_address\_name](#output\_tfe\_lb\_ip\_address\_name) | Name of IP address resource of TFE load balancer. |
| <a name="output_tfe_object_storage_google_bucket"></a> [tfe\_object\_storage\_google\_bucket](#output\_tfe\_object\_storage\_google\_bucket) | Name of TFE GCS bucket. |
| <a name="output_tfe_redis_host"></a> [tfe\_redis\_host](#output\_tfe\_redis\_host) | Hostname/IP address (and port if non-default) of TFE Redis instance. |
| <a name="output_tfe_redis_password"></a> [tfe\_redis\_password](#output\_tfe\_redis\_password) | Auth string of TFE Redis instance. |
| <a name="output_tfe_redis_password_base64"></a> [tfe\_redis\_password\_base64](#output\_tfe\_redis\_password\_base64) | Base64-encoded auth string of TFE Redis instance. |
| <a name="output_tfe_service_account_email"></a> [tfe\_service\_account\_email](#output\_tfe\_service\_account\_email) | TFE GCP service account email address. Only produced when `enable_gke_workload_identity` is `true`. |
| <a name="output_tfe_service_account_key"></a> [tfe\_service\_account\_key](#output\_tfe\_service\_account\_key) | TFE GCP service account key in JSON format, base64-encoded. Only produced when `enable_gke_workload_identity` is `false`. |
<!-- END_TF_DOCS -->