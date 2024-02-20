locals {
  service_name = "submitapi-${var.network}-${var.submitapi_version}"
  port         = 8090
}

variable "namespace" {
  description = "The namespace where the resources will be created"
}

variable "network" {
  description = "Cardano node network"

  validation {
    condition     = contains(["mainnet", "preprod", "preview"], var.network)
    error_message = "Invalid network. Allowed values are mainnet, preprod and preview."
  }
}

variable "submitapi_version" {
  type = string

  validation {
    condition     = contains(["stable", "v135"], var.submitapi_version)
    error_message = "Invalid submit api version."
  }
}

resource "kubernetes_service_v1" "well_known_service" {
  metadata {
    name      = local.service_name
    namespace = var.namespace
  }

  spec {
    port {
      name     = "api"
      protocol = "TCP"
      port     = local.port
    }

    selector = {
      "cardano.demeter.run/network" = var.network
      "cardano.demeter.run/submitapi-version" = var.submitapi_version
    }

    type = "ClusterIP"
  }
}
