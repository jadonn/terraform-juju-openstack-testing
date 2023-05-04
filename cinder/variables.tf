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

variable "config" {
    type = object({
        cinder = map(any)
    })
}

variable "units" {
    type = object({
        cinder = number
    })
}

variable "placement" {
    type = object({
        cinder = string
    })
}

variable "relation_names" {
    type = object({
        ceph_mons = string
        glance = string
        keystone = string
        mysql_innodb_cluster = string
        nova_compute = string
        nova_cloud_controller = string
        rabbitmq = string
        vault = string
    })
}