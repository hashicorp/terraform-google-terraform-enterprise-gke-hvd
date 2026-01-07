# Helm Overrides

This doc contains various customizations that are supported within your Helm overrides file for your TFE deployment.

## Scaling TFE Pods

To manage the number of pods running within your TFE deployment, set the value of the `replicaCount` key accordingly.

```yaml
replicaCount: 3
```

## Service (type `LoadBalancer`)

The module-generated Helm overrides configures a Kubernetes service of type `LoadBalancer`, which provisions a passthrough L4 TCP load balancer in Google Cloud. 

By default, this module also creates a reserved IP address (`google_compute_address`) for the Service (`create_tfe_lb_ip = true`). The Service then references that reserved address by resource name via the `networking.gke.io/load-balancer-ip-addresses` annotation.

If you set `create_tfe_lb_ip = false`, you must provide the name of an existing `google_compute_address` resource to use instead.

This Service does not terminate TLS; TLS is terminated by TFE.

### Internal (module default)

Provisions an **internal** passthrough TCP load balancer using the specified private (`INTERNAL`) reserved IP address (referenced by `google_compute_address` resource name).

```yaml
service:
  annotations:
    networking.gke.io/load-balancer-type: "Internal"
    networking.gke.io/load-balancer-ip-addresses: "<tfe-lb-internal-ip-address-name>"
  type: LoadBalancer
  port: 443
```

### External

Provisions an **external** passthrough TCP Network Load Balancer using the specified public (`EXTERNAL`) reserved IP address (referenced by `google_compute_address` resource name). With Regional Backend Services (RBS) enabled, backends are Network Endpoint Groups (NEGs) (pod IPs) rather than instance groups.

```yaml
service:
  annotations:
    cloud.google.com/l4-rbs: "enabled"
    networking.gke.io/load-balancer-ip-addresses: "<tfe-lb-external-ip-address-name>"
  type: LoadBalancer
  port: 443
```

Prior to installing this Helm configuration, you must set `tfe_lb_ip_address_type = "EXTERNAL"` in your Terraform configuration so the module creates a public (external) IP address resource instead of a private (internal) one.

## Pod anti-affinity

To ensure that TFE pods are scheduled on separate GKE nodes (one pod per node), configure required pod anti-affinity:

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app: terraform-enterprise
```

## Agent Worker Pod Template (`agentWorkerPodTemplate`)

`agentWorkerPodTemplate` is a TFE Helm chart value that accepts a Kubernetes `PodTemplateSpec`. By default, agent worker jobs run on the TFE control plane node pool; this option allows that behavior to be overridden using standard Kubernetes scheduling fields. This setting applies only to **remote** execution mode and does not affect custom, self-hosted agent pools managed outside of TFE.

```yaml
agentWorkerPodTemplate:
  spec:
    nodeSelector:
      cloud.google.com/gke-nodepool: "<gke-node-pool-name>"
```