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
        keystone = number
    })
}

variable "placement" {
    type = object({
        keystone = string
    })
}

variable "relation_names" {
    type = object({
        mysql_innodb_cluster = string
        vault = string
    })
}