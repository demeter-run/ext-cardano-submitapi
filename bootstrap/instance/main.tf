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
  description = "host:port of the node's n2c endpoint. Used by the socat balancer."
  type        = string
}

variable "node_balancer" {
  description = "Sidecar that serves /ipc/node.socket: \"socat\" forwards every session to node_private_dns; \"haproxy\" spreads sessions over the Ready members of the pool named by node_srv_record, by least connections."
  type        = string
  default     = "socat"
  nullable    = false

  validation {
    condition     = contains(["socat", "haproxy"], var.node_balancer)
    error_message = "Invalid node_balancer. Allowed values are socat or haproxy."
  }
}

variable "node_srv_record" {
  description = "DNS SRV name of a headless Service that publishes only the pool's Ready nodes, e.g. _n2c._tcp.node-mainnet-pool.ext-nodes-m1.svc.cluster.local. Required when node_balancer is haproxy."
  type        = string
  default     = null

  validation {
    condition     = var.node_srv_record == null || can(regex("^_[^.]+\\._tcp\\.[^.]+\\..+$", var.node_srv_record))
    error_message = "node_srv_record must be an SRV name of the form _<port>._tcp.<service>.<namespace>.svc.<domain>."
  }
}

variable "node_max_conn_per_server" {
  description = "With the haproxy balancer, the most sessions one node takes from this pod."
  type        = number
  default     = 200
  nullable    = false
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

variable "tolerations" {
  description = "List of tolerations for the node"
  type = list(object({
    effect   = string
    key      = string
    operator = string
    value    = optional(string)
  }))
  default = [
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-profile"
      operator = "Equal"
      value    = "general-purpose"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/compute-arch"
      operator = "Equal"
      value    = "x86"
    },
    {
      effect   = "NoSchedule"
      key      = "demeter.run/availability-sla"
      operator = "Equal"
      value    = "consistent"
    }
  ]
}
