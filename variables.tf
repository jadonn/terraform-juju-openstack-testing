variable "series" {
  type = string
}

variable "juju_model" {
  type = object({
    name  = string
    cloud = map(any)
  })
}

variable "openstack_channel" {
  type = string
}

variable "openstack_origin" {
  type = string
}

variable "ceph" {
  type = object({
    channel = string
    config  = map(any)
  })
}

variable "nova" {
  type = object({
    config    = map(any)
    units     = object({
      compute           = number
      cloud_controller  = number
    })
    placement = object({
      compute           = string
    })
  })
}

variable "mysql" {
  type = object({
    channel = string
    config = map(any)
  })
}

variable "vault" {
  type = object({
    channel   = string
    config    = map(any)
    units     = number
    placement = string
  })
}

variable "ovn" {
  type = object({
    channel = string
    central = object({
      config    = map(any)
      units     = number
      placement = string
    })
    chassis = object({
      config = map(any)
    })
  })
}

variable "neutron" {
  type = object({
    api = object({
      config    = map(any)
      units     = number
      placement = string
    })
  })
}
