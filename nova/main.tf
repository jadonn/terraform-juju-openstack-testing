terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "nova_compute" {
    model = var.model
    charm {
        name = "nova-compute"
        channel = var.channel
        series = var.series
    }

    config = var.config.compute
    
    units = var.units.compute
    placement = var.placement.compute
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "nova_cloud_controller" {
    model = var.model
    name = "nova-cloud-controller"
    charm {
        name = "nova-cloud-controller"
        channel = var.channel
        series = var.series
    }

    config = var.config.cloud_controller

    units = var.units.cloud_controller
    placement = var.placement.cloud_controller
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "ncc_mysql_router" {
    model = var.model
    name = "ncc-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.mysql.channel
        series = var.series
    }

    units = 0
    placement = juju_application.nova_cloud_controller.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "ncc_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.ncc_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "rabbitmq_nova_compute" {
    model = var.model
    application {
        name = var.relation_names.rabbitmq
        endpoint = "amqp"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "amqp"
    }
}

resource "juju_integration" "ncc_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.ncc_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "nova_cloud_controller_keystone" {
    model = var.model
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "identity-service"
    }

    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }
}

resource "juju_integration" "nova_cloud_controller_rabbitmq" {
    model = var.model
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "amqp"
    }

    application {
        name = var.relation_names.rabbitmq
        endpoint = "amqp"
    }
}

resource "juju_integration" "nova_cloud_controller_neutron_api" {
    model = var.model
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "neutron-api"
    }

    application {
        name = var.relation_names.neutron_api
        endpoint = "neutron-api"
    }
}

resource "juju_integration" "nova_cloud_controller_nova_compute" {
    model = var.model
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "cloud-compute"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "cloud-compute"
    }
}

resource "juju_integration" "nova_cloud_controller_vault" {
    model = var.model
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}


