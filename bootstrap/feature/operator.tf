locals {
  role = "operator"
  port = 9946
}

resource "kubernetes_deployment_v1" "operator" {
  wait_for_rollout = false

  metadata {
    namespace = var.namespace
    name      = local.role
    labels = {
      role = local.role
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        role = local.role
      }
    }

    template {
      metadata {
        labels = {
          role = local.role
        }
      }

      spec {
        container {
          image = "ghcr.io/demeter-run/ext-cardano-submitapi-operator:${var.operator_image_tag}"
          name  = "main"

          env {
            name  = "ADDR"
            value = "0.0.0.0:${local.port}"
          }

          env {
            name  = "K8S_IN_CLUSTER"
            value = "true"
          }

          env {
            name  = "PROMETHEUS_URL"
            value = "http://prometheus-operated.demeter-system.svc.cluster.local:9090/api/v1"
          }

          env {
            name  = "METRICS_DELAY"
            value = var.metrics_delay
          }

          env {
            name  = "DCU_PER_REQUEST"
            value = "mainnet=${var.dcu_per_request["mainnet"]},preprod=${var.dcu_per_request["preprod"]},preview=${var.dcu_per_request["preview"]},vector-testnet=${var.dcu_per_request["vector-testnet"]}"
          }

          env {
            name  = "DEFAULT_SUBMITAPI_VERSION"
            value = "stable"
          }

          env {
            name  = "API_KEY_SALT"
            value = var.api_key_salt
          }

          env {
            name  = "INGRESS_CLASS"
            value = var.ingress_class
          }

          env {
            name  = "DNS_ZONE"
            value = var.dns_zone
          }

          resources {
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
          }

          port {
            name           = "metrics"
            container_port = local.port
            protocol       = "TCP"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-profile"
          operator = "Equal"
          value    = "general-purpose"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/compute-arch"
          operator = "Equal"
          value    = "x86"
        }

        toleration {
          effect   = "NoSchedule"
          key      = "demeter.run/availability-sla"
          operator = "Equal"
          value    = "consistent"
        }
      }
    }
  }
}
