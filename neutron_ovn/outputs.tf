output "application_names" {
    value = {
        neutron_api = juju_application.neutron_api.name
    }
}