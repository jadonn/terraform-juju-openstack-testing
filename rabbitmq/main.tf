terraform {
    required_providers {
      juju = {
        version = "~> 0.8.0"
        source  = "juju/juju"
      }
    }
}

resource "juju_application" "rabbitmq" {
    model = var.juju_model
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