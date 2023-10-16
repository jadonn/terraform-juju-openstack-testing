resource "juju_model" "openstack" {
    name = var.name

    cloud {
        name    = var.cloud.name
        region  = var.cloud.region
    }

}