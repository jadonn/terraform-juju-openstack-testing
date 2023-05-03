terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

resource "juju_application" "vault" {
    model = var.model
    name = "vault"
    charm {
        name = "vault"
        channel = var.channel
        series = var.series
    }

    config = var.config.vault

    units = var.units.vault
    placement = var.placement.vault
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_application" "vault_mysql_router" {
    model = var.model
    name = "vault-mysql-router"
    charm {
        name = "mysql-router"
        channel = var.mysql.channel
        series = var.series
    }
    units = 0 // Subordinate applications cannot have units
    placement = juju_application.vault.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}

resource "juju_integration" "vault_db_router" {
    model = var.model
    application {
        name = juju_application.vault_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "db-router"
    }
}

resource "juju_integration" "vault_shared_db" {
    model = var.model
    application {
        name = juju_application.vault_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.vault.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "mysql_vault_certificates" {
    model = var.model
    application {
        name = var.relation_names.mysql_innodb_cluster
        endpoint = "certificates"
    }
    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}