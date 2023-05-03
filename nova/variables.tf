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
        compute = object({})
        cloud_controller = object({})
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
        rabbitmq = string
        vault = string
    })
}