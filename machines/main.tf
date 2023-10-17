resource "juju_machine" "openstack" {
    count = var.machine_count
    model = var.juju_model
    series = var.series
    name = "${var.name_prefix}-${count.index}"
    constraints = var.constraints
}