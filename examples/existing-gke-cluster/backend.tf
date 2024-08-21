// This is a placeholder file for the remote backend configuration.
// When deploying this module in production, you should use the GCS remote backend.
// https://developer.hashicorp.com/terraform/language/settings/backends/gcs

# terraform {
#   backend "gcs" {
#     bucket  = "tf-state-prod"
#     prefix  = "terraform/state"
#   }
# }