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
        dashboard = number
    })
}

variable "placement" {
    type = object({
        dashboard = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        vault = string
    })
}