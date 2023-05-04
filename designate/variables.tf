variable "model" {
    type = string
}

variable "channel" {
    type = object({
        openstack = string
        memcached = string
        mysql = string
    })
}

variable "series" {
    type = string
}

variable "config" {
    type = object({
        designate = map(any)
    })
}

variable "units" {
    type = object({
        designate = number
        memcached = number
    })
}

variable "placement" {
    type = object({
        designate = string
        memcached = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        neutron_api = string
        rabbitmq = string
    })
}