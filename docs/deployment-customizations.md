# Deployment Customizations

This doc contains various deployment customizations as it relates to creating your TFE infrastructure, and their corresponding module input variables that you may additionally set to meet your own requirements where the module default values do not suffice. That said, all of the module input variables on this page are optional.

## GKE

If you want to configure this module to create an GKE cluster dedicated to running TFE:

```hcl
create_gke_cluster = true
```

If you are bringing your own GKE cluster (module default):

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