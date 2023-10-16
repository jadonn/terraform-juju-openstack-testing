output "application_names" {
  value = {
    mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
  }
}