output "application_names" {
    value = {
        compute = juju_application.nova_compute.name
        cloud_controller = juju_application.nova_cloud_controller.name
    }
}