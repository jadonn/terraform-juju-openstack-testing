resource "juju_machine" "openstack" {
    count = var.machine_count
    model = var.model
    series = var.series
    name = "${var.name_prefix}-${count.index}"
    constraints = var.constraints
}