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

variable "mysql" {
    type = object({
        channel = string
    })
}

variable "config" {
    type = object({
        compute = object({})
        cloud_controller = object({})
    })
}

variable "units" {
    type = object({
        compute = number
        cloud_controller = number
    })
}

variable "placement" {
    type = object({
        compute = string
        cloud_controller = string
    })
}

variable "relation_names" {
    type = object({
        keystone = string
        mysql_innodb_cluster = string
        neutron_api = string
        rabbitmq = string
        vault = string
    })
}

output "application_names" {
    value = {
        compute = juju_application.nova_compute.name
        cloud_controller = juju_application.nova_cloud_controller.name
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


