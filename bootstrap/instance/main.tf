variable "namespace" {
  type = string
}

variable "image" {
  type = string
}

variable "salt" {
  type = string
}

variable "node_private_dns" {
  type = string
}

variable "testnet_magic" {
  type = number
}

variable "network" {
  type = string

  validation {
    condition     = contains(["mainnet", "preprod", "preview", "vector-testnet"], var.network)
    error_message = "Invalid network. Allowed values are mainnet, preprod, preview, vector-testnet."
  }
}

variable "replicas" {
  type    = number
  default = 1
}

variable "resources" {
  type = object({
    limits = object({
      cpu    = string
      memory = string
    })
    requests = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    limits : {
      cpu : "200m",
      memory : "1Gi"
    }
    requests : {
      cpu : "200m",
      memory : "500Mi"
    }
  }
}
