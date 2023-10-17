output "application_names" {
    value = {
        neutron_api = juju_application.neutron_api.name
        ovn_chassis = juju_application.ovn_chassis.name
    }
}