variable "model" {
    type = string
}

variable "channel" {
    type = object({
        openstack = string
        mysql = string
    })
}

variable "series" {
    type = string
}

variable "units" {
    type = object({
        placement = number
    })
}

variable "placement" {
    type = object({
        placement = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        nova_cloud_controller = string
        vault = string
    })
}