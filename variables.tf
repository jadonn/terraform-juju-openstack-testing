variable "series" {
    type = string
    description = "The Ubuntu series to use for charms, machines, and other artifacts."
    default = "jammy"
    validation {
        condition     = var.series != null
        error_message = "You must provide an Ubuntu series."
    }
}

variable "model" {
    type = object({
        name = string
        cloud = object({
            name = string
            region = string
        })
        config = map(any)
        constraints = string
        credential = string
    })
    description = "Input for the Juju model you would like to create to hold OpenStack."
    validation {
        condition     = var.model.name != null && var.model.cloud != null
        error_message = "You must provide a model name and cloud configuration in your model resource declaration."
    }
}

variable "ceph" {
    type = object({
        channel = string
        config = object({
            osds = map(any)
            mons = map(any)
            rgw = map(any)
        })
    })
    description = "The configuration for Ceph services."
    validation {
        condition = var.ceph.channel != null && var.ceph.config.osds != {}
        error_message = "You must provide a Ceph channel and OSD config for the charms to use when installing Ceph."
    }
}

variable "nova" {
    type = object({
        channel = string
        config = object({
            compute = map(any)
            cloud_controller = map(any)
        })
        units = object({
            compute = number
            cloud_controller = number
        })
        placement = object({
            compute = string
            cloud_controller = string
        })
    })
    description = "The configuration for the Nova Compute and Nova Cloud Controller applications."
}

variable "mysql" {
    type = object({
        channel = string
    })
    description = "The version channel of MySQL to use when deploying MySQL."
}

variable "vault" {
    type = object({
        channel = string
        config = map(any)
        units = number
        placement = string
    })
    description = "The configuration for the Vault application charm."
}

variable "networking" {
    type = object({
        neutron_api = object({
            channel = string
            config = map(any)
            units = number
            placement = string
        })
        ovn_central = object({
            channel = string
            config = map(any)
            units = number
            placement = string
        })
        ovn_chassis = object({
            channel = string
            config = map(any)
        })
    })
    description = "The configuration for the Neutron and OVN charms."
}

variable "keystone" {
    type = object({
        channel = string
        units = number
        placement = string
    })
    description = "The configuration for the Keystone charm."
}

variable "placement" {
    type = object({
        channel = string
        units = number
        placement = string
    })
    description = "The configuration for the Placement charm."
}

variable "dashboard" {
    type = object({
        channel = string
        units = number
        placement = string
    })
    description = "The configuration for the Dashboard charm."
}

variable "glance" {
    type = object({
        channel = string
        units = number
        placement = string
    })
    description = "The configuratino for the Glance charm."
}

variable "rabbitmq" {
    type = object({
        channel = string
    })
    description = "The configuration for the RabbitMQ charm."
}

variable "cinder" {
    type = object({
        channel = string
        config = map(any)
        units = number
        placement = string
    })
    description = "The configuration for the Cinder charm."
}

variable "designate" {
    type = object({
        channel = string
        config = map(any)
        units = object({
            bind = number
            designate = number
        })
        placement = object({
            bind = string
            designate = string
        })
    })
    description = "The configuration of the Designate charm."
}

variable "memcached" {
    type = object({
        channel = string
        units = number
        placement = string
    })
    description = "The configuration for the Memcached charm."
}

variable "manila" {
    type = object({
        channel = string
        units = number
        placement = string
        generic = object({
            config = map(any)
        })
    })
}