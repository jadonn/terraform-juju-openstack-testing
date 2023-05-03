output "application_names" {
    value = {
        keystone = juju_application.keystone.name
    }
}