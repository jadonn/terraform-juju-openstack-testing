terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "ovn_central" {
    model = var.model
    name = "ovn-central"
    charm {
        name = "ovn-central"
        channel = var.channel.ovn
        series = var.series
    }

    config = var.config.central
    units = var.units.central
    placement = var.placement.central
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "neutron_api" {
    model = var.model
    name = "neutron-api"
    charm {
        name = "neutron-api"
        channel = var.channel.openstack
        series = var.series
    }

    config = var.config.neutron_api

    units = var.units.neutron_api
    placement = var.placement.neutron_api
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "neutron_api_plugin_ovn" {
    model = var.model
    name = "neutron-api-plugin-ovn"
    charm {
        name = "neutron-api-plugin-ovn"
        channel = var.channel.openstack
        series = var.series
    }

    units = 0 // Subordinate charm applications cannot have units
    placement = juju_application.neutron_api.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}


resource "juju_application" "neutron_api_mysql_router" {
    model = var.model
    name = "neutron-api-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0
    placement = juju_application.neutron_api.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "ovn_chassis" {
    model = var.model
    name = "ovn-chassis"
    charm {
        name = "ovn-chassis"
        channel = var.channel.ovn
        series = var.series
    }

    config = var.config.chassis

    units = 0 // Subordinate charm applications cannot have units
    placement = juju_application.neutron_api.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "neutron_api_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.neutron_api_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "neutron_api_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.neutron_api_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "neutron_api_plugin_neutron_api" {
    model = var.model
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "neutron-plugin"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "neutron-plugin-api-subordinate"
    }
}

resource "juju_integration" "neutron_api_plugin_ovn" {
    model = var.model
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "ovsdb-cms"
    }

    application {
        name = juju_application.ovn_central.name
        endpoint = "ovsdb-cms"
    }
}

resource "juju_integration" "ovn_chassis_ovn_central" {
    model = var.model
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "ovsdb"
    }

    application {
        name = juju_application.ovn_central.name
        endpoint = "ovsdb"
    }
}

resource "juju_integration" "ovn_chassis_nova_compute" {
    model = var.model
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "nova-compute"
    }

    application {
        name = var.relation_names.nova_compute
        endpoint = "neutron-plugin"
    }
}

resource "juju_integration" "neutron_api_vault" {
    model = var.model
    application {
        name = juju_application.neutron_api.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

resource "juju_integration" "neutron_api_plugin_ovn_vault" {
    model = var.model
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

resource "juju_integration" "ovn_central_vault" {
    model = var.model
    application {
        name = juju_application.ovn_central.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

resource "juju_integration" "ovn_chassis_vault" {
    model = var.model
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

resource "juju_integration" "rabbitmq_neutron_api" {
    model = var.model
    application {
        name = var.relation_names.rabbitmq
        endpoint = "amqp"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "amqp"
    }
}

resource "juju_integration" "keystone_neutron_api" {
    model = var.model
    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "identity-service"
    }
}