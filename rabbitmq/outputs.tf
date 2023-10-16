output "application_names" {
  value = {
    rabbitmq = juju_application.rabbitmq.name
  }
}