terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

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
        osds = object({})
        mons = object({})
        rgw = object({})
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

resource "juju_application" "ceph_osds" {
    model = var.model
    charm {
        name = "ceph-osd"
        channel = var.channel
        series = var.series
    }
    config = var.config.osds
    units = var.units.osds
    placement = var.placement.osds
}

resource "juju_application" "ceph_mon" {
    model = var.model
    name = "ceph-mon"
    charm {
        name = "ceph-mon"
        channel = var.channel
        series = var.series
    }

    units = var.units.mons
    placement = var.placement.mons
}

resource "juju_application" "ceph_radosgw" {
    model = var.model
    name = "ceph-radosgw"
    charm {
        name = "ceph-radosgw"
        channel = var.channel
        series = var.series
    }

    units = var.units.rgw
    placement = var.placement.rgw
}

resource "juju_integration" "ceph_mon_ceph_osd" {
    model = var.model
    application {
        name = juju_application.ceph_mon.name
        endpoint = "osd"
    }

    application {
        name = juju_application.ceph_osds.name
        endpoint = "mon"
    }
}

resource "juju_integration" "ceph_mon_nova_compute" {
    model = var.model
    application {
        name = juju_application.ceph_mon.name
        endpoint = "client"
    }

    application {
        name = var.relation_names.nova
        endpoint = "ceph"
    }
}

resource "juju_integration" "ceph_mon_glance" {
    model = var.model
    application {
        name = juju_application.ceph_mon.name
        endpoint = "client"
    }

    application {
        name = var.relation_names.glance
        endpoint = "ceph"
    }
}

resource "juju_integration" "ceph_radosgw_ceph_mon" {
    model = var.model
    application {
        name = juju_application.ceph_radosgw.name
        endpoint = "mon"
    }

    application {
        name = juju_application.ceph_mon.name
        endpoint = "radosgw"
    }
}