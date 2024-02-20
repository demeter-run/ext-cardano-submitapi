variable "namespace" {
  type = string
}

variable "image" {
  type = string
}

variable "submitapi_version" {
  type = string

  validation {
    condition     = contains(["stable", "v135"], var.submitapi_version)
    error_message = "Invalid submit api version."
  }
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
    condition     = contains(["mainnet", "preprod", "preview"], var.network)
    error_message = "Invalid network. Allowed values are mainnet, preprod and preview."
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
