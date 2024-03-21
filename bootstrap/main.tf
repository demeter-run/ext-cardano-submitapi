resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

module "submitapi_v1_feature" {
  depends_on         = [kubernetes_namespace.namespace]
  source             = "./feature"
  namespace          = var.namespace
  operator_image_tag = var.operator_image_tag
  metrics_delay      = var.metrics_delay
  ingress_class      = var.ingress_class
  dns_zone           = var.dns_zone
  api_key_salt       = var.api_key_salt
  dcu_per_request    = var.dcu_per_request
}

module "submitapi_v1_proxy" {
  depends_on      = [kubernetes_namespace.namespace]
  source          = "./proxy"
  proxy_image_tag = var.proxy_image_tag
  namespace       = var.namespace
  replicas        = var.proxy_replicas
  resources       = var.proxy_resources
  dns_zone        = var.dns_zone
  networks        = var.networks
  extension_name  = var.extension_name
}

module "submitapi_configs" {
  depends_on = [kubernetes_namespace.namespace]
  for_each   = { for network in var.networks : "${network}" => network }

  source    = "./configs"
  namespace = var.namespace
  network   = each.value
}

module "submitapi_instances" {
  depends_on = [kubernetes_namespace.namespace, module.submitapi_configs]
  for_each   = var.instances
  source     = "./instance"

  namespace        = var.namespace
  image            = each.value.image
  salt             = each.value.salt
  node_private_dns = each.value.node_private_dns
  testnet_magic    = each.value.testnet_magic
  network          = each.value.network
  replicas         = coalesce(each.value.replicas, 1)
  resources = coalesce(each.value.resources, {
    limits : {
      cpu : "200m",
      memory : "1Gi"
    }
    requests : {
      cpu : "200m",
      memory : "500Mi"
    }
  })
}

module "submitapi_services" {
  depends_on = [kubernetes_namespace.namespace]
  for_each   = { for network in var.networks : "${network}" => network }
  source     = "./service"

  namespace = var.namespace
  network   = each.value.network
}

