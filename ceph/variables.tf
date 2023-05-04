variable "model" {
    type = string
}

variable "channel" {
    type = string
}

variable "series" {
    type = string
}

variable "config" {
    type = object({
        osds = map(any)
        mons = map(any)
        rgw = map(any)
    })
}

variable "units" {
    type = object({
        osds = number
        mons = number
        rgw = number
    })
}

variable "placement" {
    type = object({
        osds = string
        mons = string
        rgw = string
    })
}

variable "relation_names" {
    type = object({
        nova = string
        glance = string
    })
}
