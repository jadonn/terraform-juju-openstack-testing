output "application_names" {
    value = {
        manila = juju_application.manila.name
    }
}