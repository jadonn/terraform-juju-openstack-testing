terraform {
    required_providers {
        juju = {
            version = "~> 0.8.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "cinder" {
    model = var.model
    name = "cinder"
    charm {
        name = "cinder"
        channel = var.channel.openstack
        series = var.series
    }

    config = var.config.cinder

    units = var.units.cinder
    placement = var.placement.cinder
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "cinder_mysql_router" {
    model = var.model
    name = "cinder-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.channel.mysql
        series = var.series
    }

    units = 0 # Subordinate charms must have 0 units
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "cinder_mysql_router_db_router" {
    model = var.model
    application {
        name = juju_application.cinder_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "cinder_mysql_router_shared_db" {
    model = var.model
    application {
        name = juju_application.cinder_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.cinder.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "cinder_nova_cloud_controller" {
    model = var.model
    application {
        name = juju_application.cinder.name
        endpoint = "cinder-volume-service"
    }

    application {
        name = var.relation_names.nova_cloud_controller
        endpoint = "cinder-volume-service"
    }
}

resource "juju_integration" "cinder_keystone" {
    model = var.model
    application {
        name = juju_application.cinder.name
        endpoint = "identity-service"
    }

    application {
        name = var.relation_names.keystone
        endpoint = "identity-service"
    }
}

resource "juju_integration" "cinder_rabbitmq" {
    model = var.model
    application {
        name = juju_application.cinder.name
        endpoint = "amqp"
    }

    application {
        name = var.relation_names.rabbitmq
        endpoint = "amqp"
    }
}

resource "juju_integration" "cinder_glance" {
    model = var.model
    application {
        name = juju_application.cinder.name
        endpoint = "image-service"
    }

    application {
        name = var.relation_names.glance
        endpoint = "image-service"
    }
}

resource "juju_integration" "cinder_vault" {
    model = var.model
    application {
        name = juju_application.cinder.name
        endpoint = "certificates"
    }

    application {
        name = var.relation_names.vault
        endpoint = "certificates"
    }
}

resource "juju_application" "cinder_ceph" {
    model = var.model
    name = "cinder-ceph"
    charm {
        name = "cinder-ceph"
        channel = var.channel.openstack
        series = var.series
    }

    units = 0 # Subordinate charms must have 0 units
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "cinder_ceph_cinder" {
    model = var.model
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "storage-backend"
    }

    application {
        name = juju_application.cinder.name
        endpoint = "storage-backend"
    }
}

resource "juju_integration" "cinder_ceph_ceph_mon" {
    model = var.model
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "ceph"
    }

    application {
        name = var.relation_names.ceph_mons
        endpoint = "client"
    }
}

resource "juju_integration" "cinder_ceph_nova_compute" {
    model = var.model
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "ceph-access"
    }

    application {
        name = var.relation_names.nova_compute
        endpoint = "ceph-access"
    }
}
