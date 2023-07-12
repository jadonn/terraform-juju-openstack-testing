terraform {
    required_providers {
        juju = {
            version = "~> 0.8.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "designate" {
    model = var.model
    name = "designate"
    charm {
        name = "designate"
        channel = var.channel.openstack
        series = var.series
    }
    config = var.config.designate
    units = var.units.designate
    placement = var.placement.designate
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "designate_bind" {
    model = var.model
    name = "designate-bind"
    charm {
        name = "designate-bind"
        channel = var.channel.openstack
        series = var.series
    }
    units = var.units.bind
    placement = var.placement.bind
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "designate_designate_bind" {
    model = var.model
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.designate_bind.name
    }
}

resource "juju_application" "memcached" {
    model = var.model
    name = "memcached"
    charm {
        name = "memcached"
        channel = var.channel.memcached
        series = var.series
    }
    units = var.units.memcached
    placement = var.placement.memcached
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "designate_mysql_router" {
    model = var.model
    name = "designate-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }
    units = 0
    placement = juju_application.designate.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "designate_memcached" {
    model = var.model
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.memcached.name
    }
}

resource "juju_integration" "designate_shared_db" {
    model = var.model
    application {
        name = juju_application.designate.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.designate_mysql_router.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "designate_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.designate_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "designate_rabbitmq" {
    model = var.model
    application {
        name = juju_application.designate.name
    }

    application {
        name = var.relation_names.rabbitmq
    }
}

resource "juju_integration" "designate_keystone" {
    model = var.model
    application {
        name = juju_application.designate.name
    }

    application {
        name = var.relation_names.keystone
    }
}

resource "juju_integration" "designate_neutron_api" {
    model = var.model
    application {
        name = juju_application.designate.name
    }

    application {
        name = var.relation_names.neutron_api
    }
}

