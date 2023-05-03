terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
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
    placement = juju_application.manila.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "manila_mysql" {
    model = var.model
    application {
        name = juju_application.manila.name
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
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
