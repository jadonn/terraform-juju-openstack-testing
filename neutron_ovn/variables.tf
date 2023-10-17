variable "model" {
    type = string
}

variable "channel" {
    type = object({
        openstack = string
        mysql = string
        ovn = string
    })
}

variable "series" {
    type = string
}

variable "config" {
    type = object({
        central = map(any)
        chassis = map(any)
        neutron_api = map(any)
    })
}

variable "units" {
    type = object({
        central = number
        neutron_api = number
    })
}

variable "placement" {
    type = object({
        central = string
        neutron_api = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        nova_compute = string
        rabbitmq = string
        vault = string
    })
}