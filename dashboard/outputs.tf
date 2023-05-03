output "application_names" {
    value = {
        dashboard = juju_application.openstack_dashboard.name
    }
}