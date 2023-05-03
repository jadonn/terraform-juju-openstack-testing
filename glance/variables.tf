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
        glance = number
    })
}

variable "placement" {
    type = object({
        glance = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        nova_cloud_controller = string
        nova_compute = string
        vault = string
    })
}