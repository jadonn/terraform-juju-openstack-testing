output "application_names" {
    value = {
        glance = juju_application.glance.name
    }
}