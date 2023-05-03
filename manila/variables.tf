variable "model" {
    type = string
}

variable "channel" {
    type = object({
        openstack = string
    })
}

variable "series" {
    type = string
}

variable "config" {
    type = object({
        manila = object({})
        manila_generic = object({})
    })
}

variable "units" {
    type = object({
        manila = number
    })
}

variable "placement" {
    type = object({
        manila = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        rabbitmq = string
    })
}