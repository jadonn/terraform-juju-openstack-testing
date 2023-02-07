terraform {
    required_providers {
        juju = {
            version = "~> 0.3.1"
            source = "juju/juju"
        }
        openstack = {
            source = "terraform-provider-openstack/openstack"
            version = "~> 1.48.0"
        }
    }
}

provider "juju" {
}

resource "juju_model" "ovb" {
    name ="ovb"

    cloud {
        name = "maas-ovb"
    }

}

resource "juju_machine" "ovb_one" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-one"
    constraints = "tags=compute"
}

resource "juju_machine" "ovb_two" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-two"
    constraints = "tags=compute"
}

resource "juju_machine" "ovb_three" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-three"
    constraints = "tags=compute"
}

resource "juju_machine" "ovb_four" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-four"
    constraints = "tags=compute"
}

locals {
    ovb_one_id = split(":", juju_machine.ovb_one.id)[1]
    ovb_two_id = split(":", juju_machine.ovb_two.id)[1]
    ovb_three_id = split(":", juju_machine.ovb_three.id)[1]
    ovb_four_id = split(":", juju_machine.ovb_four.id)[1]
}

resource "juju_application" "ceph_osds" {
    model = juju_model.ovb.name
    charm {
        name = "ceph-osd"
        channel = "quincy/stable"
        series = "jammy"
    }
    config = {
        osd-devices = "/dev/vdb"
        source = "distro"
    }
    units = 4
    placement = join(",", [split(":", juju_machine.ovb_one.id)[1], split(":", juju_machine.ovb_two.id)[1], split(":", juju_machine.ovb_three.id)[1], split(":", juju_machine.ovb_four.id)[1]])
}

resource "juju_application" "nova_compute" {
    model = juju_model.ovb.name
    charm {
        name = "nova-compute"
        channel = "yoga/stable"
        series = "jammy"
    }

    config = {
        config-flags = "default_ephemeral_format=ext4"
        enable-live-migration = "true"
        enable-resize = "true"
        migration-auth-type = "ssh"
        virt-type = "qemu"
        openstack-origin = "distro"
    }
    
    units = 3
    placement = join(",", [local.ovb_one_id, local.ovb_two_id, local.ovb_three_id])
}

resource "juju_application" "mysql_innodb_cluster" {
    model = juju_model.ovb.name
    name = "mysql-innodb-cluster" // Needed the name or you get an error about how application- is an invalid application tag
    charm {
        name = "mysql-innodb-cluster"
        channel = "8.0/stable"
    }

    units = 3
    placement = "${local.ovb_one_id},${local.ovb_two_id},${local.ovb_three_id}"
}

resource "juju_application" "vault" {
    model = juju_model.ovb.name
    name = "vault"
    charm {
        name = "vault"
        channel = "1.7/stable"
    }

    config = {
        totally-unsecure-auto-unlock = "true"
        auto-generate-root-ca-cert = "true"
    }

    units = 1
    placement = "lxd:${local.ovb_three_id}"
}

resource "juju_application" "vault_mysql_router" {
    model = juju_model.ovb.name
    name = "vault-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
    }
    units = 0 // Subordinate applications cannot have units
    placement = juju_application.vault.placement
}

resource "juju_integration" "vault_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.vault_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "vault_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.vault_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.vault.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "mysql_vault_certificates" {
    model = juju_model.ovb.name
    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "certificates"
    }
    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "ovn_central" {
    model = juju_model.ovb.name
    name = "ovn-central"
    charm {
        name = "ovn-central"
        channel = "22.03/stable"
    }

    config = {
        source = "distro"
    }
    units = 3
    placement = "lxd:${local.ovb_one_id},lxd:${local.ovb_two_id},lxd:${local.ovb_three_id}"
}

resource "juju_application" "neutron_api" {
    model = juju_model.ovb.name
    name = "neutron-api"
    charm {
        name = "neutron-api"
        channel = "yoga/stable"
    }

    config = {
        neutron-security-groups = "true"
        flat-network-providers = "physnet1"
        openstack-origin = "distro"
    }

    units = 1
    placement = "lxd:${local.ovb_two_id}"
}

resource "juju_application" "neutron_api_plugin_ovn" {
    model = juju_model.ovb.name
    name = "neutron-api-plugin-ovn"
    charm {
        name = "neutron-api-plugin-ovn"
        channel = "yoga/stable"
    }

    units = 0 // Subordinate charm applications cannot have units
    placement = juju_application.neutron_api.placement
}

resource "juju_application" "ovn_chassis" {
    model = juju_model.ovb.name
    name = "ovn-chassis"
    charm {
        name = "ovn-chassis"
        channel = "22.03/stable"
    }

    config = {
        bridge-interface-mappings = "br-ex:ens3" // You must update the device name ens3 to whatever your networking device name is
        ovn-bridge-mappings = "physnet1:br-ex"
    }

    units = 0 // Subordinate charm applications cannot have units
    placement = juju_application.neutron_api.placement
}

resource "juju_integration" "neutron_api_plugin_neutron_api" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "neutron-plugin"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "neutron-plugin-api-subordinate"
    }
}

resource "juju_integration" "neutron_api_plugin_ovn" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "ovsdb-cms"
    }

    application {
        name = juju_application.ovn_central.name
        endpoint = "ovsdb-cms"
    }
}

resource "juju_integration" "ovn_chassis_ovn_central" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "ovsdb"
    }

    application {
        name = juju_application.ovn_central.name
        endpoint = "ovsdb"
    }
}

resource "juju_integration" "ovn_chassis_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "nova-compute"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "neutron-plugin"
    }
}

resource "juju_integration" "neutron_api_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_integration" "neutron_api_plugin_ovn_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api_plugin_ovn.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_integration" "ovn_central_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ovn_central.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_integration" "ovn_chassis_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ovn_chassis.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "neutron_api_mysql_router" {
    model = juju_model.ovb.name
    name = "neutron-api-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
    }

    units = 0
    placement = juju_application.neutron_api.placement
}

resource "juju_integration" "neutron_api_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "neutron_api_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.neutron_api_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "shared-db"
    }
}

resource "juju_application" "keystone" {
    model = juju_model.ovb.name
    name = "keystone"
    charm {
        name = "keystone"
        channel = "yoga/stable"
    }

    units = 1
    placement = "lxd:${local.ovb_one_id}"
}

resource "juju_application" "keystone_mysql_router" {
    model = juju_model.ovb.name
    name = "keystone-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
    }

    units = 0 // Subordinate charms cannot have units
    placement = juju_application.keystone.placement
}

resource "juju_integration" "keystone_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.keystone_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "keystone_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.keystone_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "keystone_neutron_api" {
    model = juju_model.ovb.name
    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "keystone_vault_certificates" {
    model = juju_model.ovb.name
    application {
        name = juju_application.keystone.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "rabbitmq" {
    model = juju_model.ovb.name
    name = "rabbitmq-server"
    charm {
        name = "rabbitmq-server"
        channel = "3.9/stable"
    }

    units = 1
    placement = "lxd:${local.ovb_four_id}"
}

resource "juju_integration" "rabbitmq_neutron_api" {
    model = juju_model.ovb.name
    application {
        name = juju_application.rabbitmq.name
        endpoint = "amqp"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "amqp"
    }
}

resource "juju_integration" "rabbitmq_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.rabbitmq.name
        endpoint = "amqp"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "amqp"
    }
}

resource "juju_application" "nova_cloud_controller" {
    model = juju_model.ovb.name
    name = "nova-cloud-controller"
    charm {
        name = "nova-cloud-controller"
        channel = "yoga/stable"
    }

    config = {
        network-manager = "Neutron"
        openstack-origin = "distro"
    }

    units = 1
    placement = "lxd:${local.ovb_four_id}"
}

resource "juju_application" "ncc_mysql_router" {
    model = juju_model.ovb.name
    name = "ncc-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
    }

    units = 0
    placement = juju_application.nova_cloud_controller.placement
}

resource "juju_integration" "ncc_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ncc_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "ncc_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ncc_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "nova_cloud_controller_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "nova_cloud_controller_rabbitmq" {
    model = juju_model.ovb.name
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "amqp"
    }

    application {
        name = juju_application.rabbitmq.name
        endpoint = "amqp"
    }
}

resource "juju_integration" "nova_cloud_controller_neutron_api" {
    model = juju_model.ovb.name
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "neutron-api"
    }

    application {
        name = juju_application.neutron_api.name
        endpoint = "neutron-api"
    }
}

resource "juju_integration" "nova_cloud_controller_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "cloud-compute"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "cloud-compute"
    }
}

resource "juju_integration" "nova_cloud_controller_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "placement" {
    model = juju_model.ovb.name
    name = "placement"
    charm {
        name = "placement"
        channel = "yoga/stable"
    }

    units = 1
    placement = "lxd:${local.ovb_four_id}"
}

resource "juju_application" "placement_mysql_router" {
    model = juju_model.ovb.name
    name = "placement-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
    }

    units = 0
    placement = juju_application.placement.placement
}

resource "juju_integration" "placement_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.placement_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "placement_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.placement_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.placement.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "placement_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.placement.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "placement_nova_cloud_controller" {
    model = juju_model.ovb.name
    application {
        name = juju_application.placement.name
        endpoint = "placement"
    }

    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "placement"
    }
}

resource "juju_integration" "placement_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.placement.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}