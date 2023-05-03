terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
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
    lifecycle {
        ignore_changes = [ placement, ]
    }
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
    lifecycle {
        ignore_changes = [ placement, ]
    }
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
