output "application_names" {
    value = {
        vault = juju_application.vault.name
    }
}
