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
