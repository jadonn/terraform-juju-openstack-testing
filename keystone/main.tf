resource "juju_application" "keystone" {
    model = var.model
    name = "keystone"
    charm {
        name = "keystone"
        channel = var.channel.openstack
        series = var.series
    }

    units = var.units.keystone
    placement = var.placement.keystone
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "keystone_mysql_router" {
    model = var.model
    name = "keystone-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0 // Subordinate charms cannot have units
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "keystone_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.keystone_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "keystone_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.keystone_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "keystone_vault_certificates" {
    model = var.model
    application {
        name = juju_application.keystone.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}