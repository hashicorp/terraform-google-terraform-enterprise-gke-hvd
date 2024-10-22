# Terraform Enterprise HVD on GCP GKE

Terraform module aligned with HashiCorp Validated Designs (HVD) to deploy Terraform Enterprise on Google Kubernetes Engine (GKE). This module supports bringing your own GKE cluster, or optionally creating a new GKE cluster dedicated to running TFE. This module does not use the Kubernetes or Helm Terraform providers, but rather includes [Post Steps](#post-steps) for the application layer portion of the deployment leveraging the `kubectl` and `helm` CLIs.

## Prerequisites

### General

- TFE license file (_e.g._ `terraform.hclic`)
- Terraform CLI (version `>= 1.9`) installed on workstation
- General understanding of how to use Terraform (Community Edition)
- General understaning of how to use Google Cloud Platform (GCP)
- General understanding of how to use Kubernetes and Helm
- `gcloud` CLI installed on workstation
- `kubectl` CLI and `helm` CLI installed on workstation
- `git` CLI and Visual Studio Code code editor installed on worksation are strongly recommended
- GCP project that TFE will be deployed in with permissions to provision these [resources](#resources) via Terraform CLI
- (Optional) GCS bucket for [GCS remote state backend](https://developer.hashicorp.com/terraform/language/settings/backends/gcs) that will be used to manage the Terraform state of this TFE deployment (out-of-band from the TFE application) via Terraform CLI (Community Edition)

### Networking

- VPC network that TFE will be deployed in
- Private Service Access (PSA) configured in VPC to enable private connectivity from GKE cluster/TFE pods to Cloud SQL for PostgreSQL and Memorystore for Redis
- Subnet for GKE cluster (if `create_gke_cluster` is `true`). It is highly recommended that the subnet has Private Google Access enabled for private connectivity from GKE cluster to Google Cloud Storage.
- Static IP address for TFE load balancer (whether to be associated with a Kubernetes service or ingress controller load balancer)
- Chosen fully qualified domain name (FQDN) for TFE (_e.g._ `tfe.gcp.example.com`)

#### Firewall rules

- Allow `TCP:443` ingress to TFE load balancer subnet from CIDR ranges of TFE users/clients, VCS, and any other systems that needs to access TFE
- Allow `TCP:443` ingress to GKE/TFE pods subnet from source IP ranges listed [here](https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges) for GCP load balancer health check probes
- (Optional) Allow `TCP:9091` (HTTPS) and `TCP:9090` (HTTP) ingress to GKE/TFE pods subnet from CIDR ranges of your monitoring/observability tool (for scraping TFE metrics endpoints)
- Allow `TCP:8443` (HTTPS) and `TCP:8080` (HTTP) ingress to GKE/TFE pods subnet from TFE load balancer subnet (for TFE application traffic)
- Allow `TCP:5432` ingress to database subnet from GKE/TFE pods subnet (for PostgreSQL traffic)
- Allow `TCP:6379` ingress to Redis subnet from GKE/TFE pods subnet (for Redis TLS traffic)
- Allow `TCP:8201` between nodes on GKE/TFE pods subnet (for TFE embedded Vault internal cluster traffic)
- Allow `TCP:443` egress to Terraform endpoints listed [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress) from GKE/TFE pods subnet
- If your GKE cluster is private, your client/workstation must be able to access the control plane via `kubectl` and `helm`
- Be familiar with the [TFE ingress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#ingress)
- Be familiar with the [TFE egress requirements](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/requirements/network#egress)

### TLS certificates

- TLS certificate (_e.g._ `cert.pem`) and private key (_e.g._ `privkey.pem`) that matches your chosen fully qualified domain name (FQDN) for TFE
  - TLS certificate and private key must be in PEM format
  - Private key must **not** be password protected
- TLS certificate authority (CA) bundle (_e.g._ `ca_bundle.pem`) corresponding with the CA that issues your TFE TLS certificates
  - CA bundle must be in PEM format
  - You may include additional certificate chains corresponding to external systems that TFE will make outbound connections to (_e.g._ your self-hosted VCS, if its certificate was issued by a different CA than your TFE certificate)

### Secret management

GCP Secret Manager secrets:

- PostgreSQL database password secret

### Compute (optional)

If you plan to create a new GKE cluster using this module, then you may skip this section. Otherwise:

- GKE cluster

## Usage

1. Create/configure/validate the applicable [prerequisites](#prerequisites).

2. Nested within the [examples](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/examples/) directory are subdirectories that contain ready-made Terraform configurations of example scenarios for how to call and deploy this module. To get started, choose an example scenario. If you are starting without an existing GKE cluster, then you should select the [new-gke](examples/new-gke) example scenario.

3. Copy all of the Terraform files from your example scenario of choice into a new destination directory to create your Terraform configuration that will manage your TFE deployment. If you are not sure where to create this new directory, it is common for users to create an `environments/` directory at the root of this repo (once you have cloned it down locally), and then a subdirectory for each TFE instance deployment, like so:

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

6. Navigate to the directory of your newly created Terraform configuration for your TFE deployment, and run `terraform init`, `terraform plan`, and `terraform apply`.

**The TFE infrastructure resources have now been created. Next comes the application layer portion of the deployment (which we refer to as the Post Steps), which will involve interacting with your GKE cluster via `kubectl` and installing the TFE application via `helm`.**

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

   >📝 Note: You can name it something different than `tfe` if you prefer. If you do name it differently, be sure to update your value of the `tfe_kube_namespace` and `tfe_kube_svc_account` input variables accordingly (the Helm chart will automatically create a Kubernetes service account for TFE based on the name of the namespace).

9. Create the required secrets for your TFE deployment within your new Kubernetes namespace for TFE. There are several ways to do this, whether it be from the CLI via `kubectl`, or another method involving a third-party secrets helper/tool. See the [Kubernetes-Secrets](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/kubernetes-secrets.md) doc for details on the required secrets and how to create them.

10. This Terraform module will automatically generate a Helm overrides file within your Terraform working directory named `./helm/module_generated_helm_overrides.yaml`. This Helm overrides file contains values interpolated from some of the infrastructure resources that were created by Terraform in step 6. Within the Helm overrides file, update or validate the values for the remaining settings that are enclosed in the `<>` characters. You may also add any additional configuration settings into your Helm overrides file at this time (see the [Helm-Overrides](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/helm-overrides.md) doc for more details).

11. Now that you have customized your `module_generated_helm_overrides.yaml` file, rename it to something more applicable to your deployment, such as `prod_tfe_overrides.yaml` (or whatever you prefer). Then, within your `terraform.tfvars` file, set the value of `create_helm_overrides_file` to `false`, as we no longer want the Terraform module to manage this file or generate a new one on a subsequent Terraform run.

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

17. Follow the remaining steps [here](https://developer.hashicorp.com/terraform/enterprise/flexible-deployments/install/kubernetes/install#4-create-initial-admin-user) to finish the installation setup, which involves creating the **initial admin user**.

## Docs

Below are links to various docs related to the customization and management of your TFE deployment:

- [Deployment Customizations](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/deployment-customizations.md)
- [Helm Overrides](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/helm-overrides.md)
- [TFE Version Upgrades](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/tfe-version-upgrades.md)
- [TFE TLS Certificate Rotation](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/tfe-cert-rotation.md)
- [TFE Configuration Settings](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs/tfe-config-settings.md)
- [TFE Kubernetes Secrets](https://github.com/hashicorp/terraform-google-terraform-enterprise-gke-hvd/tree/main/docs-kubernetes-secrets.md)

## Module support

This open source software is maintained by the HashiCorp Technical Field Organization, independently of our enterprise products. While our Support Engineering team provides dedicated support for our enterprise offerings, this open source software is not included.

- For help using this open source software, please engage your account team.
- To report bugs/issues with this open source software, please open them directly against this code repository using the GitHub issues feature.

Please note that there is no official Service Level Agreement (SLA) for support of this software as a HashiCorp customer. This software falls under the definition of Community Software/Versions in your Agreement. We appreciate your understanding and collaboration in improving our open source projects.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.42 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 5.42 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 5.42 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | ~> 5.42 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.5.1 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.2 |

## Resources

| Name | Type |
|------|------|
| [google-beta_google_project_service_identity.cloud_sql_sa](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_compute_address.tfe_lb](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address) | resource |
| [google_container_cluster.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_dns_record_set.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_kms_crypto_key_iam_binding.cloud_sql_sa_postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_binding) | resource |
| [google_kms_crypto_key_iam_binding.gcp_project_gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_binding) | resource |
| [google_kms_crypto_key_iam_binding.redis_sa_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_binding) | resource |
| [google_project_iam_member.gke_artifact_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_default_node_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_metric_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_object_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_stackdriver_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_redis_instance.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance) | resource |
| [google_service_account.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.tfe](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.tfe_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_dns_zone_name"></a> [cloud\_dns\_zone\_name](#input\_cloud\_dns\_zone\_name) | Name of Google Cloud DNS managed zone to create TFE DNS record in. Only valid when `create_cloud_dns_record` is `true`. | `string` | `null` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Common labels to apply to all GCP resources. | `map(string)` | `{}` | no |
| <a name="input_create_gke_cluster"></a> [create\_gke\_cluster](#input\_create\_gke\_cluster) | Boolean to create a GKE cluster. | `bool` | `false` | no |
| <a name="input_create_helm_overrides_file"></a> [create\_helm\_overrides\_file](#input\_create\_helm\_overrides\_file) | Boolean to generate a YAML file from template with Helm overrides values for your TFE deployment. Set this to `false` after your initial TFE deployment is complete, as we no longer want the Terraform module to manage it (since you will be customizing it further). | `bool` | `true` | no |
| <a name="input_create_tfe_cloud_dns_record"></a> [create\_tfe\_cloud\_dns\_record](#input\_create\_tfe\_cloud\_dns\_record) | Boolean to create Google Cloud DNS record for TFE using the value of `tfe_fqdn` for the record name. | `bool` | `false` | no |
| <a name="input_create_tfe_lb_ip"></a> [create\_tfe\_lb\_ip](#input\_create\_tfe\_lb\_ip) | Boolean to create a static IP address for TFE load balancer (load balancer is created/managed by Helm/Kubernetes). | `bool` | `true` | no |
| <a name="input_enable_gke_workload_identity"></a> [enable\_gke\_workload\_identity](#input\_enable\_gke\_workload\_identity) | Boolean to enable GCP workload identity with GKE cluster. | `bool` | `true` | no |
| <a name="input_friendly_name_prefix"></a> [friendly\_name\_prefix](#input\_friendly\_name\_prefix) | Prefix used to name all GCP resources uniquely. It is most common to use either an environment (e.g. 'sandbox', 'prod'), a team name, or a project name here. | `string` | n/a | yes |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Boolean indicating whether to allow force destroying the TFE GCS bucket. GCS bucket can be destroyed if it is not empty when `true`. | `bool` | `false` | no |
| <a name="input_gcs_kms_cmek_name"></a> [gcs\_kms\_cmek\_name](#input\_gcs\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. | `string` | `null` | no |
| <a name="input_gcs_kms_keyring_name"></a> [gcs\_kms\_keyring\_name](#input\_gcs\_kms\_keyring\_name) | Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for TFE GCS bucket encryption. Geographic location (region) of the key ring must match the location of the TFE GCS bucket. | `string` | `null` | no |
| <a name="input_gcs_location"></a> [gcs\_location](#input\_gcs\_location) | Location of TFE GCS bucket to create. | `string` | `"US"` | no |
| <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class) | Storage class of TFE GCS bucket. | `string` | `"MULTI_REGIONAL"` | no |
| <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access) | Boolean to enable uniform bucket level access on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled) | Boolean to enable versioning on TFE GCS bucket. | `bool` | `true` | no |
| <a name="input_gke_cluster_is_private"></a> [gke\_cluster\_is\_private](#input\_gke\_cluster\_is\_private) | Boolean indicating if GKE network access is private cluster. | `bool` | `true` | no |
| <a name="input_gke_cluster_name"></a> [gke\_cluster\_name](#input\_gke\_cluster\_name) | Name of GKE cluster to create. | `string` | `"tfe-gke-cluster"` | no |
| <a name="input_gke_control_plane_authorized_cidr"></a> [gke\_control\_plane\_authorized\_cidr](#input\_gke\_control\_plane\_authorized\_cidr) | CIDR block allowed to access GKE control plane. | `string` | `null` | no |
| <a name="input_gke_control_plane_cidr"></a> [gke\_control\_plane\_cidr](#input\_gke\_control\_plane\_cidr) | Control plane IP range of private GKE cluster. Must not overlap with any subnet in GKE cluster's VPC. | `string` | `"10.0.10.0/28"` | no |
| <a name="input_gke_deletion_protection"></a> [gke\_deletion\_protection](#input\_gke\_deletion\_protection) | Boolean to enable deletion protection on GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_enable_private_endpoint"></a> [gke\_enable\_private\_endpoint](#input\_gke\_enable\_private\_endpoint) | Boolean to enable private endpoint on GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_http_load_balancing_disabled"></a> [gke\_http\_load\_balancing\_disabled](#input\_gke\_http\_load\_balancing\_disabled) | Boolean to enable HTTP load balancing on GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_l4_ilb_subsetting_enabled"></a> [gke\_l4\_ilb\_subsetting\_enabled](#input\_gke\_l4\_ilb\_subsetting\_enabled) | Boolean to enable layer 4 ILB subsetting on GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_node_count"></a> [gke\_node\_count](#input\_gke\_node\_count) | Number of GKE nodes per zone | `number` | `1` | no |
| <a name="input_gke_node_pool_name"></a> [gke\_node\_pool\_name](#input\_gke\_node\_pool\_name) | Name of node pool to create in GKE cluster. | `string` | `"tfe-gke-node-pool"` | no |
| <a name="input_gke_node_type"></a> [gke\_node\_type](#input\_gke\_node\_type) | Size/machine type of GKE nodes. | `string` | `"e2-standard-4"` | no |
| <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel) | The channel to use for how frequent Kubernetes updates and features are received. | `string` | `"REGULAR"` | no |
| <a name="input_gke_remove_default_node_pool"></a> [gke\_remove\_default\_node\_pool](#input\_gke\_remove\_default\_node\_pool) | Boolean to remove the default node pool in GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_subnet_name"></a> [gke\_subnet\_name](#input\_gke\_subnet\_name) | Name or self\_link to existing VPC subnetwork to create GKE cluster in. | `string` | `null` | no |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL for PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time) | HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC. | `string` | `"00:00"` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `50` | no |
| <a name="input_postgres_insights_config"></a> [postgres\_insights\_config](#input\_postgres\_insights\_config) | Configuration settings for Cloud SQL for PostgreSQL insights. | <pre>object({<br/>    query_insights_enabled  = bool<br/>    query_plans_per_minute  = number<br/>    query_string_length     = number<br/>    record_application_tags = bool<br/>    record_client_address   = bool<br/>  })</pre> | <pre>{<br/>  "query_insights_enabled": false,<br/>  "query_plans_per_minute": 5,<br/>  "query_string_length": 1024,<br/>  "record_application_tags": false,<br/>  "record_client_address": false<br/>}</pre> | no |
| <a name="input_postgres_kms_cmek_name"></a> [postgres\_kms\_cmek\_name](#input\_postgres\_kms\_cmek\_name) | Name of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_kms_keyring_name"></a> [postgres\_kms\_keyring\_name](#input\_postgres\_kms\_keyring\_name) | Name of Cloud KMS Key Ring that contains KMS key to use for Cloud SQL for PostgreSQL. Geographic location (region) of key ring must match the location of the TFE Cloud SQL for PostgreSQL database instance. | `string` | `null` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL for PostgreSQL instance. | `string` | `"db-custom-4-16384"` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Optional maintenance window settings for the Cloud SQL for PostgreSQL instance. | <pre>object({<br/>    day          = number<br/>    hour         = number<br/>    update_track = string<br/>  })</pre> | <pre>{<br/>  "day": 7,<br/>  "hour": 0,<br/>  "update_track": "stable"<br/>}</pre> | no |
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
| <a name="input_tfe_database_password_secret_version"></a> [tfe\_database\_password\_secret\_version](#input\_tfe\_database\_password\_secret\_version) | Name of PostgreSQL database password secret to retrieve from GCP Secret Manager. | `string` | n/a | yes |
| <a name="input_tfe_database_user"></a> [tfe\_database\_user](#input\_tfe\_database\_user) | Name of TFE PostgreSQL database user to create. | `string` | `"tfe"` | no |
| <a name="input_tfe_fqdn"></a> [tfe\_fqdn](#input\_tfe\_fqdn) | Fully qualified domain name of TFE instance. This name should eventually resolve to the TFE load balancer DNS name or IP address and will be what clients use to access TFE. | `string` | n/a | yes |
| <a name="input_tfe_http_port"></a> [tfe\_http\_port](#input\_tfe\_http\_port) | HTTP port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `8080` | no |
| <a name="input_tfe_https_port"></a> [tfe\_https\_port](#input\_tfe\_https\_port) | HTTPS port number that the TFE application will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `8443` | no |
| <a name="input_tfe_kube_namespace"></a> [tfe\_kube\_namespace](#input\_tfe\_kube\_namespace) | Name of Kubernetes namespace for TFE (created by Helm chart). Used to configure GCP workload identity with GKE. | `string` | `"tfe"` | no |
| <a name="input_tfe_kube_svc_account"></a> [tfe\_kube\_svc\_account](#input\_tfe\_kube\_svc\_account) | Name of Kubernetes Service Account for TFE (created by Helm chart). Used to configure GCP workload identity with GKE. | `string` | `"tfe"` | no |
| <a name="input_tfe_lb_ip_address"></a> [tfe\_lb\_ip\_address](#input\_tfe\_lb\_ip\_address) | IP address to assign to TFE load balancer. Must be a valid IP address from `tfe_lb_subnet_name` when `tfe_lb_ip_address_type` is `INTERNAL`. | `string` | `null` | no |
| <a name="input_tfe_lb_ip_address_type"></a> [tfe\_lb\_ip\_address\_type](#input\_tfe\_lb\_ip\_address\_type) | Type of IP address to assign to TFE load balancer. Valid values are 'INTERNAL' or 'EXTERNAL'. | `string` | `"INTERNAL"` | no |
| <a name="input_tfe_lb_subnet_name"></a> [tfe\_lb\_subnet\_name](#input\_tfe\_lb\_subnet\_name) | Name or self\_link to existing VPC subnetwork to create TFE internal load balancer IP address in. | `string` | `null` | no |
| <a name="input_tfe_metrics_http_port"></a> [tfe\_metrics\_http\_port](#input\_tfe\_metrics\_http\_port) | HTTP port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `9090` | no |
| <a name="input_tfe_metrics_https_port"></a> [tfe\_metrics\_https\_port](#input\_tfe\_metrics\_https\_port) | HTTPS port number that the TFE metrics endpoint will listen on within the TFE pods. It is recommended to leave this as the default value. | `number` | `9091` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of existing VPC network to create resources in. | `string` | n/a | yes |
| <a name="input_vpc_project_id"></a> [vpc\_project\_id](#input\_vpc\_project\_id) | ID of GCP Project where the existing VPC resides if it is different than the default project. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gke_cluster_name"></a> [gke\_cluster\_name](#output\_gke\_cluster\_name) | Name of TFE GKE cluster. |
| <a name="output_redis_server_ca_certs"></a> [redis\_server\_ca\_certs](#output\_redis\_server\_ca\_certs) | CA certificate of TFE Redis instance. Add this to your TFE CA bundle. |
| <a name="output_tfe_database_host"></a> [tfe\_database\_host](#output\_tfe\_database\_host) | IP address and port of TFE Cloud SQL for PostgreSQL database instance. |
| <a name="output_tfe_database_instance_id"></a> [tfe\_database\_instance\_id](#output\_tfe\_database\_instance\_id) | ID of TFE Cloud SQL for PostgreSQL database instance. |
| <a name="output_tfe_database_password"></a> [tfe\_database\_password](#output\_tfe\_database\_password) | TFE PostgreSQL database password. |
| <a name="output_tfe_database_password_base64"></a> [tfe\_database\_password\_base64](#output\_tfe\_database\_password\_base64) | Base64-encoded TFE PostgreSQL database password. |
| <a name="output_tfe_lb_ip_address"></a> [tfe\_lb\_ip\_address](#output\_tfe\_lb\_ip\_address) | IP address of TFE load balancer. |
| <a name="output_tfe_lb_ip_address_name"></a> [tfe\_lb\_ip\_address\_name](#output\_tfe\_lb\_ip\_address\_name) | Name of IP address resource of TFE load balancer. |
| <a name="output_tfe_object_storage_google_bucket"></a> [tfe\_object\_storage\_google\_bucket](#output\_tfe\_object\_storage\_google\_bucket) | Name of TFE GCS bucket. |
| <a name="output_tfe_redis_host"></a> [tfe\_redis\_host](#output\_tfe\_redis\_host) | Hostname/IP address (and port if non-default) of TFE Redis instance. |
| <a name="output_tfe_redis_password"></a> [tfe\_redis\_password](#output\_tfe\_redis\_password) | Auth string of TFE Redis instance. |
| <a name="output_tfe_redis_password_base64"></a> [tfe\_redis\_password\_base64](#output\_tfe\_redis\_password\_base64) | Base64-encoded auth string of TFE Redis instance. |
| <a name="output_tfe_service_account_email"></a> [tfe\_service\_account\_email](#output\_tfe\_service\_account\_email) | TFE GCP service account email address. Only produced when `enable_gke_workload_identity` is `true`. |
| <a name="output_tfe_service_account_key"></a> [tfe\_service\_account\_key](#output\_tfe\_service\_account\_key) | TFE GCP service account key in JSON format, base64-encoded. Only produced when `enable_gke_workload_identity` is `false`. |
<!-- END_TF_DOCS -->
