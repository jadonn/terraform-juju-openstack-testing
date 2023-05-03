output "application_names" {
    value = {
        designate = juju_application.designate.name
    }
}