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
        vault = object({})
    })
}

variable "units" {
    type = object({
        vault = number
    })
}

variable "placement" {
    type = object({
        vault = string
    })
}

variable "relation_names" {
    type = object({
        mysql_innodb_cluster = string
    })
}