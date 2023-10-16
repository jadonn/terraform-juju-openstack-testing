output "machine_ids" {
  value = [for machine in juju_machine.openstack: split(":", machine.id)[1]]
}