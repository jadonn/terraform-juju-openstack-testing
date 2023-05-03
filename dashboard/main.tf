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

output "application_names" {
    value = {
        dashboard = juju_application.openstack_dashboard.name
    }
}

resource "juju_application" "openstack_dashboard" {
    model = var.model
    name = "openstack-dashboard"
    charm {
        name = "openstack-dashboard"
        channel = var.channel.openstack
        series = var.series
    }

    units = var.units.dashboard
    placement = var.placement.dashboard
}

resource "juju_application" "openstack_dashboard_mysql_router" {
    model = var.model
    name = "dashboard-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0 # Subordinate charms must have 0 units
    placement = juju_application.openstack_dashboard.placement
}

resource "juju_integration" "dashboard_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.openstack_dashboard_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "dashboard_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.openstack_dashboard_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "openstack_dashboard_keystone" {
    model = var.model
    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "identity-service"
    }

    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }
}

resource "juju_integration" "openstack_dashboard_vault" {
    model = var.model
    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

