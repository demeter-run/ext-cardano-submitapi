locals {
  name           = "submitapi-${var.network}-${var.salt}"
  container_port = 8090

  haproxy       = var.node_balancer == "haproxy"
  haproxy_image = "haproxy:3.2-alpine@sha256:1392e5f7a83ddf820b020fe2b099f08a2311a9b8e9212c0285119dd13903ff1c"
  haproxy_config = local.haproxy ? templatefile("${path.module}/haproxy.cfg.tftpl", {
    # Empty only when the precondition below rejects the instance.
    srv_record          = var.node_srv_record == null ? "" : var.node_srv_record
    server_slots        = 8
    max_conn_per_server = var.node_max_conn_per_server
  }) : null
}

resource "kubernetes_config_map_v1" "haproxy" {
  count = local.haproxy ? 1 : 0

  metadata {
    name      = "${local.name}-haproxy"
    namespace = var.namespace
  }

  data = {
    "haproxy.cfg" = local.haproxy_config
  }

  lifecycle {
    precondition {
      condition     = var.node_srv_record != null
      error_message = "node_srv_record is required when node_balancer is haproxy."
    }
  }
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
        # Rolls the pods when the balancer config changes.
        annotations = local.haproxy ? {
          "checksum/haproxy-config" = sha256(local.haproxy_config)
        } : null
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

        dynamic "container" {
          for_each = local.haproxy ? [] : [1]

          content {
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
        }

        dynamic "container" {
          for_each = local.haproxy ? [1] : []

          content {
            name              = "haproxy"
            image             = local.haproxy_image
            image_pull_policy = "IfNotPresent"

            resources {
              limits = {
                memory = "128Mi"
              }
              requests = {
                cpu    = "25m"
                memory = "64Mi"
              }
            }

            security_context {
              run_as_non_root            = true
              run_as_user                = 1000
              run_as_group               = 1000
              allow_privilege_escalation = false
            }

            volume_mount {
              name       = "ipc"
              mount_path = "/ipc"
            }

            volume_mount {
              name       = "haproxy-config"
              mount_path = "/usr/local/etc/haproxy"
              read_only  = true
            }
          }
        }

        volume {
          name = "ipc"
          empty_dir {}
        }

        dynamic "volume" {
          for_each = local.haproxy ? [1] : []

          content {
            name = "haproxy-config"

            config_map {
              name = kubernetes_config_map_v1.haproxy[0].metadata[0].name
            }
          }
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

