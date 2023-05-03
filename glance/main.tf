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

output "application_names" {
    value = {
        glance = juju_application.glance.name
    }
}

resource "juju_application" "glance" {
    model = var.model
    name = "glance"
    charm {
        name = "glance"
        channel = var.channel.openstack
        series = var.series
    }

    units = var.units.glance
    placement = var.placement.glance
}

resource "juju_application" "glance_mysql_router" {
    model = var.model
    name = "glance-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0 # Subordinate charms must have 0 units
    placement = juju_application.glance.placement
}

resource "juju_integration" "glance_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.glance_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "glance_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.glance_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.glance.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "glance_nova_cloud_controller" {
    model = var.model
    application {
        name = juju_application.glance.name
        endpoint = "image-service"
    }

    application {
        name = var.relation_names.nova_cloud_controller
        endpoint = "image-service"
    }
}

resource "juju_integration" "glance_nova_compute" {
    model = var.model
    application {
        name = juju_application.glance.name
        endpoint = "image-service"
    }

    application {
        name = var.relation_names.nova_compute
        endpoint = "image-service"
    }
}

resource "juju_integration" "glance_keystone" {
    model = var.model
    application {
        name = juju_application.glance.name
        endpoint = "identity-service"
    }

    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }
}

resource "juju_integration" "glance_vault" {
    model = var.model
    application {
        name = juju_application.glance.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}
