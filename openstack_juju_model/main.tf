terraform {
    required_providers {
      juju = {
        version = "~> 0.8.0"
        source  = "juju/juju"
      }
    }
}
resource "juju_model" "openstack" {
    name = var.name

    cloud {
        name    = var.cloud.name
        region  = var.cloud.region
    }
}