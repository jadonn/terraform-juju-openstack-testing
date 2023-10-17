resource "juju_application" "rabbitmq" {
    model = var.model
    name = "rabbitmq-server"
    charm {
        name = "rabbitmq-server"
        channel = var.channel
        series = var.series
    }

    units = var.units
    placement = var.placement
    lifecycle {
        ignore_changes = [ placement, ]
    }
}