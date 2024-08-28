# Helm Overrides

This doc contains various customizations that are supported within your Helm overrides file for your TFE deployment.

## Scaling TFE Pods

To manage the number of pods running within your TFE deployment, set the value of the `replicaCount` key accordingly.

```yaml
replicaCount: 3
```

## Service (type `LoadBalancer`)

By default, the module-generated Helm overrides will configure a Kubernetes service of type `LoadBalancer`. The service will automatically provision an internal passthrough Network Load Balancer with the specified private (`INTERNAL`) IP address that was created by this Terraform module (referenced by name).

### Internal (default)

```yaml
service:
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
    networking.gke.io/load-balancer-ip-addresses: "tfe-lb-internal-ip"
  type: LoadBalancer
  port: 443
```

### External

If want to configure an external load balancer, you can set the annotations as follows:

```yaml
service:
  annotations:
    cloud.google.com/l4-rbs: "enabled"
    networking.gke.io/load-balancer-ip-addresses: "tfe-lb-external-ip"
  type: LoadBalancer
  port: 443
```

In this configuration, the service will automatically provision a backend service-based external passthrough Network Load Balancer. Prior to installing this Helm configuration, you need to set `tfe_lb_ip_address_type` to `EXTERNAL` within your Terraform configuration so the module will create an external (public) IP address resource rather than internal (private).