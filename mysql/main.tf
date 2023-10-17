resource "juju_application" "mysql_innodb_cluster" {
    model = var.juju_model
    name = "mysql-innodb-cluster" // Needed the name or you get an error about how application- is an invalid application tag
    charm {
        name = "mysql-innodb-cluster"
        channel = var.channel
        series = var.series
    }

    units = var.units
    placement = var.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}