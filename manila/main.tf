terraform {
    required_providers {
        juju = {
            version = "~> 0.8.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "manila" {
    model = var.model
    name = "manila"
    charm {
        name = "manila"
        channel = var.channel.openstack
        series = var.series
    }
    config = var.config.manila
    units = var.units.manila
    placement = var.placement.manila
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "manila_generic" {
    model = var.model
    name = "manila-generic"
    charm {
        name = "manila-generic"
        channel = var.channel.openstack
        series = var.series
    }
    config = var.config.manila_generic
    units = 0 // Subordinate applications cannot have units
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "manila_mysql_router" {
    model = var.model
    name = "manila-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }
    units = 0
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "manila_shared_db" {
    model = var.model
    application {
        name = juju_application.manila.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.manila_mysql_router.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "manila_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.manila_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "manila_rabbitmq" {
    model = var.model
    application {
        name = juju_application.manila.name
    }

    application {
        name = var.relation_names.rabbitmq
    }
}

resource "juju_integration" "manila_keystone" {
    model = var.model
    application {
        name = juju_application.manila.name
    }
    
    application {
        name = var.relation_names.keystone
    }
}

resource "juju_integration" "manila_manila_generic" {
    model = var.model
    application {
        name = juju_application.manila.name
        endpoint = "manila-plugin"
    }

    application {
        name = juju_application.manila_generic.name
        endpoint = "manila-plugin"
    }
}
