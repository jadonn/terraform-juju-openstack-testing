output "application_names" {
    value = {
        placement = juju_application.placement.name
    }
}