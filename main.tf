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

locals {
    series = "jammy"
    openstack_channel = "yoga/stable"
}

resource "juju_model" "ovb" {
    name ="ovb"

    cloud {
        name = "maas-ovb"
        region = "default"
    }

}

resource "juju_machine" "hyperconverged" {
    count = 3
    model = juju_model.ovb.name
    series = local.series
    name = "hyperconverged-${count.index}"
    constraints = "tags=hyperconverged"
}

locals {
    hyperconverged_juju_ids = [for machine in juju_machine.hyperconverged: split(":", machine.id)[1]]
}

resource "juju_application" "ceph_osds" {
    model = juju_model.ovb.name
    charm {
        name = "ceph-osd"
        channel = "quincy/stable"
        series = local.series
    }
    config = {
        osd-devices = "/dev/vdb"
        source = "distro"
    }
    units = 3
    placement = join(",", local.hyperconverged_juju_ids)
}

resource "juju_application" "nova_compute" {
    model = juju_model.ovb.name
    charm {
        name = "nova-compute"
        channel = "yoga/stable"
        series = local.series
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
    placement = join(",", local.hyperconverged_juju_ids)
}

resource "juju_application" "mysql_innodb_cluster" {
    model = juju_model.ovb.name
    name = "mysql-innodb-cluster" // Needed the name or you get an error about how application- is an invalid application tag
    charm {
        name = "mysql-innodb-cluster"
        channel = "8.0/stable"
        series = local.series
    }

    units = 3
    placement = join(",", local.hyperconverged_juju_ids)
}

resource "juju_application" "vault" {
    model = juju_model.ovb.name
    name = "vault"
    charm {
        name = "vault"
        channel = "1.7/stable"
        series = local.series
    }

    config = {
        totally-unsecure-auto-unlock = "true"
        auto-generate-root-ca-cert = "true"
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[0]}"
}

resource "juju_application" "vault_mysql_router" {
    model = juju_model.ovb.name
    name = "vault-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
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
        series = local.series
    }

    config = {
        source = "distro"
    }
    units = 3
    placement = join(",", [for id in local.hyperconverged_juju_ids: "lxd:${id}"])
}

resource "juju_application" "neutron_api" {
    model = juju_model.ovb.name
    name = "neutron-api"
    charm {
        name = "neutron-api"
        channel = "yoga/stable"
        series = local.series
    }

    config = {
        neutron-security-groups = "true"
        flat-network-providers = "physnet1"
        openstack-origin = "distro"
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "neutron_api_plugin_ovn" {
    model = juju_model.ovb.name
    name = "neutron-api-plugin-ovn"
    charm {
        name = "neutron-api-plugin-ovn"
        channel = "yoga/stable"
        series = local.series
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
        series = local.series
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
        series = local.series
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
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "keystone_mysql_router" {
    model = juju_model.ovb.name
    name = "keystone-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
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
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[0]}"
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
        series = local.series
    }

    config = {
        network-manager = "Neutron"
        openstack-origin = "distro"
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "ncc_mysql_router" {
    model = juju_model.ovb.name
    name = "ncc-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
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
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "placement_mysql_router" {
    model = juju_model.ovb.name
    name = "placement-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
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

resource "juju_application" "openstack_dashboard" {
    model = juju_model.ovb.name
    name = "openstack-dashboard"
    charm {
        name = "openstack-dashboard"
        channel = "yoga/stable"
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[0]}"
}

resource "juju_application" "openstack_dashboard_mysql_router" {
    model = juju_model.ovb.name
    name = "dashboard-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
    }

    units = 0
    placement = juju_application.openstack_dashboard.placement
}

resource "juju_integration" "dashboard_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.openstack_dashboard_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "dashboard_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.openstack_dashboard_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "openstack_dashboard_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "openstack_dashboard_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.openstack_dashboard.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "glance" {
    model = juju_model.ovb.name
    name = "glance"
    charm {
        name = "glance"
        channel = "yoga/stable"
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "glance_mysql_router" {
    model = juju_model.ovb.name
    name = "glance-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
    }

    units = 0
    placement = juju_application.glance.placement
}

resource "juju_integration" "glance_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "glance_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.glance.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "glance_nova_cloud_controller" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance.name
        endpoint = "image-service"
    }

    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "image-service"
    }
}

resource "juju_integration" "glance_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance.name
        endpoint = "image-service"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "image-service"
    }
}

resource "juju_integration" "glance_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "glance_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.glance.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "ceph_mon" {
    model = juju_model.ovb.name
    name = "ceph-mon"
    charm {
        name = "ceph-mon"
        channel = "quincy/stable"
        series = local.series
    }

    units = 3
    placement = join(",", [for id in local.hyperconverged_juju_ids: "lxd:${id}"])
}

resource "juju_integration" "ceph_mon_ceph_osd" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ceph_mon.name
        endpoint = "osd"
    }

    application {
        name = juju_application.ceph_osds.name
        endpoint = "mon"
    }
}

resource "juju_integration" "ceph_mon_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ceph_mon.name
        endpoint = "client"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "ceph"
    }
}

resource "juju_integration" "ceph_mon_glance" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ceph_mon.name
        endpoint = "client"
    }

    application {
        name = juju_application.glance.name
        endpoint = "ceph"
    }
}

resource "juju_application" "cinder" {
    model = juju_model.ovb.name
    name = "cinder"
    charm {
        name = "cinder"
        channel = "yoga/stable"
        series = local.series
    }

    config = {
        block-device = "None"
        glance-api-version = "2"
        openstack-origin = "distro"
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "cinder_mysql_router" {
    model = juju_model.ovb.name
    name = "cinder-mysql-router"
    charm {
        name = "mysql-router"
        channel = "8.0/stable"
        series = local.series
    }

    units = 0
    placement = juju_application.cinder.placement
}

resource "juju_integration" "cinder_mysql_router_db_router" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder_mysql_router.name
        endpoint = "db-router"
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
        endpoint = "db-router"
    }
}

resource "juju_integration" "cinder_mysql_router_shared_db" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder_mysql_router.name
        endpoint = "shared-db"
    }

    application {
        name = juju_application.cinder.name
        endpoint = "shared-db"
    }
}

resource "juju_integration" "cinder_nova_cloud_controller" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder.name
        endpoint = "cinder-volume-service"
    }

    application {
        name = juju_application.nova_cloud_controller.name
        endpoint = "cinder-volume-service"
    }
}

resource "juju_integration" "cinder_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder.name
        endpoint = "identity-service"
    }

    application {
        name = juju_application.keystone.name
        endpoint = "identity-service"
    }
}

resource "juju_integration" "cinder_rabbitmq" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder.name
        endpoint = "amqp"
    }

    application {
        name = juju_application.rabbitmq.name
        endpoint = "amqp"
    }
}

resource "juju_integration" "cinder_glance" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder.name
        endpoint = "image-service"
    }

    application {
        name = juju_application.glance.name
        endpoint = "image-service"
    }
}

resource "juju_integration" "cinder_vault" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder.name
        endpoint = "certificates"
    }

    application {
        name = juju_application.vault.name
        endpoint = "certificates"
    }
}

resource "juju_application" "cinder_ceph" {
    model = juju_model.ovb.name
    name = "cinder-ceph"
    charm {
        name = "cinder-ceph"
        channel = "yoga/stable"
        series = local.series
    }

    units = 0
    placement = juju_application.cinder.placement
}

resource "juju_integration" "cinder_ceph_cinder" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "storage-backend"
    }

    application {
        name = juju_application.cinder.name
        endpoint = "storage-backend"
    }
}

resource "juju_integration" "cinder_ceph_ceph_mon" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "ceph"
    }

    application {
        name = juju_application.ceph_mon.name
        endpoint = "client"
    }
}

resource "juju_integration" "cinder_ceph_nova_compute" {
    model = juju_model.ovb.name
    application {
        name = juju_application.cinder_ceph.name
        endpoint = "ceph-access"
    }

    application {
        name = juju_application.nova_compute.name
        endpoint = "ceph-access"
    }
}

resource "juju_application" "ceph_radosgw" {
    model = juju_model.ovb.name
    name = "ceph-radosgw"
    charm {
        name = "ceph-radosgw"
        channel = "quincy/stable"
        series = local.series
    }

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_integration" "ceph_radosgw_ceph_mon" {
    model = juju_model.ovb.name
    application {
        name = juju_application.ceph_radosgw.name
        endpoint = "mon"
    }

    application {
        name = juju_application.ceph_mon.name
        endpoint = "radosgw"
    }
}

resource "juju_application" "designate" {
    model = juju_model.ovb.name
    name = "designate"
    charm {
        name = "designate"
        channel = local.openstack_channel
        series = local.series
    }
    config {
        nameservers = "ns1.not-a-real-domain.com. ns2.not-a-real-domain.com."
    }
    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "designate_bind" {
    model = juju_model.ovb.name
    name = "designate-bind"
    charm {
        name = "designate-bind"
        channel = local.openstack_channel
        series = local.series
    }
    units = 1
    placement = juju_application.designate.placement
}

resource "juju_integration" "designate_designate_bind" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.designate_bind.name
    }
}

resource "juju_application" "memcached" {
    model = juju_model.ovb.name
    name = "memcached"
    charm {
        name = "memcached"
        channel = "latest/stable"
        series = local.series
    }
    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[0]}"
}

resource "juju_integration" "designate_memcached" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.memcached.name
    }
}

resource "juju_integration" "designate_mysql" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
    }
}

resource "juju_integration" "designate_rabbitmq" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.rabbitmq.name
    }
}

resource "juju_integration" "designate_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.keystone.name
    }
}

resource "juju_integration" "designate_neutron_api" {
    model = juju_model.ovb.name
    application {
        name = juju_application.designate.name
    }

    application {
        name = juju_application.neutron_api.name
    }
}

resource "juju_application" "manila" {
    model = juju_model.ovb.name
    name = "manila"
    charm {
        name = "manila"
        channel = local.openstack_channel
        series = local.series
    }
    config = {
        default-share-backend = "generic"
    }
    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "manila_generic" {
    model = juju_model.ovb.name
    name = "manila-generic"
    charm {
        name = "manila-generic"
        channel = local.openstack_channel
        series = local.series
    }
    config = {
        driver-service-instance-flavor-id = "1000" // This needs a value of a real image ID
    }
    units = 0 // Subordinate applications cannot have units
    placement = juju_application.manila.placement
}

resource "juju_integration" "manila_mysql" {
    model = juju_model.ovb.name
    application {
        name = juju_application.manila.name
    }

    application {
        name = juju_application.mysql_innodb_cluster.name
    }
}

resource "juju_integration" "manila_rabbitmq" {
    model = juju_model.ovb.name
    application {
        name = juju_application.manila.name
    }

    application {
        name = juju_application.rabbitmq.name
    }
}

resource "juju_integration" "manila_keystone" {
    model = juju_model.ovb.name
    application {
        name = juju_application.manila.name
    }
    
    application {
        name = juju_application.keystone.name
    }
}

resource "juju_integration" "manila_manila_generic" {
    model = juju_model.ovb.name
    application {
        name = juju_application.manila.name
        endpoint = "manila-plugin"
    }

    application {
        name = juju_application.manila_generic.name
        endoint = "manila-plugin"
    }
}

