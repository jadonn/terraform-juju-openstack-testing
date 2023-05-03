output "application_names" {
    value = {
        cinder = juju_application.cinder.name
    }
}