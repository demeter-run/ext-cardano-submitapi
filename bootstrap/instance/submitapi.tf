locals {
  name           = "submitapi-${var.network}-${var.salt}"
  container_port = 8090
}

resource "kubernetes_deployment_v1" "submitapi" {
  wait_for_rollout = false

  metadata {
    name      = local.name
    namespace = var.namespace
    labels = {
      "demeter.run/kind"            = "SubmitApiInstance"
      "cardano.demeter.run/network" = var.network
    }
  }

  spec {
    replicas = var.replicas

    strategy {
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }
    selector {
      match_labels = {
        "demeter.run/instance"        = local.name
        "cardano.demeter.run/network" = var.network
      }
    }

    template {

      metadata {
        name = local.name
        labels = {
          "demeter.run/instance"        = local.name
          "cardano.demeter.run/network" = var.network
        }
      }

      spec {
        restart_policy = "Always"

        security_context {
          fs_group = 1000
        }

        container {
          name              = "main"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          args = var.network == "vector-testnet" ? [
            "--mainnet",
            "--config",
            "/config/submit-api-config.json",
            "--socket-path",
            "/ipc/node.socket",
            "--port",
            local.container_port,
            "--listen-address",
            "0.0.0.0",
            ] : [
            "--testnet-magic",
            var.testnet_magic,
            "--config",
            "/config/submit-api-config.json",
            "--socket-path",
            "/ipc/node.socket",
            "--port",
            local.container_port,
            "--listen-address",
            "0.0.0.0",
          ]

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
            container_port = local.container_port
            name           = "api"
          }

          volume_mount {
            name       = "node-config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "ipc"
            mount_path = "/ipc"
          }
        }

        container {
          name  = "socat"
          image = "alpine/socat"
          args = [
            "UNIX-LISTEN:/ipc/node.socket,reuseaddr,fork,unlink-early",
            "TCP-CONNECT:${var.node_private_dns}"
          ]

          security_context {
            run_as_user  = 1000
            run_as_group = 1000
          }

          volume_mount {
            name       = "ipc"
            mount_path = "/ipc"
          }
        }

        volume {
          name = "ipc"
          empty_dir {}
        }

        volume {
          name = "node-config"
          config_map {
            name = "configs-${var.network}"
          }
        }

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            effect   = toleration.value.effect
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
          }
        }
      }
    }
  }
}

