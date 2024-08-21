replicaCount: 1
tls:
  certificateSecret: <tfe-certs>
  caCertData: |
    <base64-encoded TFE CA bundle>

image:
  repository: images.releases.hashicorp.com
  name: hashicorp/terraform-enterprise
  tag: <v202408-1>

%{ if enable_gke_workload_identity ~}
serviceAccount:
  annotations: 
    # Workload identity
    iam.gke.io/gcp-service-account: ${tfe_service_account_email}
%{ endif ~}

tfe:
  privateHttpPort: ${tfe_http_port}
  privateHttpsPort: ${tfe_https_port}
  metrics:
    enable: <true>
    httpPort: ${tfe_metrics_http_port}
    httpsPort: ${tfe_metrics_https_port}

service:
  annotations:
%{ if tfe_lb_type == "External" ~}    
    cloud.google.com/l4-rbs: "enabled"
%{ else ~}
    networking.gke.io/load-balancer-type: "${tfe_lb_type}"
%{ endif ~}
    networking.gke.io/load-balancer-ip-addresses: "${tfe_lb_ip_address}"
  type: LoadBalancer
  port: 443
  #loadBalancerIP: "<tfe-lb-static-ip>" # Only use if not creating IP address via Terraform module

env:
  secretRefs:
    - name: <tfe-secrets>
  
  variables:
    # TFE config settings
    TFE_HOSTNAME: ${tfe_hostname}

    # Database settings
    TFE_DATABASE_HOST: ${tfe_database_host}
    TFE_DATABASE_NAME: ${tfe_database_name}
    TFE_DATABASE_USER: ${tfe_database_user}
    TFE_DATABASE_PARAMETERS: ${tfe_database_parameters}

    # Object storage settings
    TFE_OBJECT_STORAGE_TYPE: ${tfe_object_storage_type}
    TFE_OBJECT_STORAGE_GOOGLE_BUCKET: ${tfe_object_storage_google_bucket}
    TFE_OBJECT_STORAGE_GOOGLE_PROJECT: ${tfe_object_storage_google_project}

    # Redis settings
    TFE_REDIS_HOST: ${tfe_redis_host}
    TFE_REDIS_USE_AUTH: ${tfe_redis_use_auth}
    TFE_REDIS_USE_TLS: ${tfe_redis_use_tls}
    
