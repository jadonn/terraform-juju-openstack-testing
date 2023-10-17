variable "model" {
    type = string
}

variable "channel" {
    type = string
}

variable "series" {
    type = string
}

variable "mysql" {
    type = object({
        channel = string
    })
}

variable "config" {
    type = object({
        compute = map(any)
        cloud_controller = map(any)
    })
}

variable "units" {
    type = object({
        compute = number
        cloud_controller = number
    })
}

variable "placement" {
    type = object({
        compute = string
        cloud_controller = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        neutron_api = string
        ovn_chassis = string
        rabbitmq = string
        vault = string
    })
}