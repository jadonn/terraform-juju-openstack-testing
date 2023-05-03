terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "placement" {
    model = var.model
    name = "placement"
    charm {
        name = "placement"
        channel = var.channel.openstack
        series = var.series
    }

    units = var.units.placement
    placement = var.placement.placement
}

resource "juju_application" "placement_mysql_router" {
    model = var.model
    name = "placement-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0 # Subordinate charms must have 0 units
    placement = juju_application.placement.placement
}

resource "juju_integration" "placement_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.placement_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "placement_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.placement_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.placement.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "placement_keystone" {
    model = var.model
    application {
        name = juju_application.placement.name
        endpoint = "identity-service"
    }

    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }
}

resource "juju_integration" "placement_nova_cloud_controller" {
    model = var.model
    application {
        name = juju_application.placement.name
        endpoint = "placement"
    }

    application {
        name = var.relation_names.nova_cloud_controller
        endpoint = "placement"
    }
}

resource "juju_integration" "placement_vault" {
    model = var.model
    application {
        name = juju_application.placement.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}
