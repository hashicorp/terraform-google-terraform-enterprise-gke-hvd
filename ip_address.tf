#------------------------------------------------------------------------------
# TFE load balancer IP address
#------------------------------------------------------------------------------
resource "google_compute_address" "tfe_lb" {
  count = var.create_tfe_lb_ip ? 1 : 0

  name         = "tfe-lb-${lower(var.tfe_lb_ip_address_type)}-ip"
  subnetwork   = var.tfe_lb_ip_address_type == "INTERNAL" ? data.google_compute_subnetwork.tfe_lb[0].self_link : null
  address_type = var.tfe_lb_ip_address_type
  address      = var.tfe_lb_ip_address
}