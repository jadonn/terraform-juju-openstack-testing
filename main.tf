terraform {
    required_providers {
        juju = {
            version = "~> 0.6.0"
            source = "juju/juju"
        }
    }
}

provider "juju" {
}

locals {
    series = "jammy"
}

locals {
    model = {
        name = "ovb"
        cloud = {
            name = "maas-ovb"
            region = "default"
        }
    }
}

locals {
    openstack = {
        channel = "yoga/stable"
        origin = "distro"
    }
}

locals {
    ceph = {
        channel = "quincy/stable"
        config = {
            osds = {
                osd-devices = "/dev/vdb"
                source = "distro"
            }
            mons = {}
            rgw = {}
        }
    }
}

locals {
    nova = {
        config = {
            compute = {
                config_flags = "default_ephemeral_format=ext4"
                enable_live_migration = "true"
                enable_resize = "true"
                migration_auth_type = "ssh"
                virt_type = "qemu"
            }
            cloud_controller = {
                network-manager = "Neutron"
                openstack-origin = "distro"
            }
        }
        units = {
            compute = 3
            cloud_controller = 1
        }
        placement = {
            compute = join(",", local.hyperconverged_juju_ids)
            cloud_controller = "lxd:${local.hyperconverged_juju_ids[1]}"
        }
    }
}

locals {
    mysql = {
        channel = "8.0/stable"
    }
}

locals {
    vault = {
        channel = "1.7/stable"
        config = {
            totally-unsecure-auto-unlock = "true"
            auto-generate-root-ca-cert = "true"
        }
    }
}

locals {
    ovn = {
        channel = "22.03/stable"
        central = {
            config = {
                source = "distro"
            }
        }
        chassis = {
            config = {
                bridge-interface-mappings = "br-ex:ens3" // You must update the device name ens3 to whatever your networking device name is
                ovn-bridge-mappings = "physnet1:br-ex"
            }
        }
    }
}

locals {
    neutron = {
        api = {
            config = {
                neutron-security-groups = "true"
                flat-network-providers = "physnet1"
                openstack-origin = "distro"                
            }
        }
    }
}

locals {
    rabbitmq = {
        channel = "3.9/stable"
    }
}

locals {
    cinder = {
        config = {
            block-device = "None"
            glance-api-version = "2"
            openstack-origin = "distro"
        }
    }
}

locals {
    designate = {
        config = {
            nameservers = "ns1.not-a-real-domain.com. ns2.not-a-real-domain.com."
        }
    }
}

locals {
    manila = {
        config = {
            default-share-backend = "generic"
        }
        generic = {
            config = {
                driver-service-instance-flavor-id = "1000" // This needs a value of a real image ID
            }
        }
    }
}

resource "juju_model" "ovb" {
    name = local.model.name

    cloud {
        name = local.model.cloud.name
        region = local.model.cloud.region
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

module "nova" {
    source = "./nova"
    model = juju_model.ovb.name
    channel = local.openstack.channel
    series = local.series
    mysql = {
        channel = local.mysql.channel
    }
    config = local.nova.config
    units = local.nova.units
    placement = local.nova.placement
    relation_names = {
        keystone = juju_application.keystone.name
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        neutron_api = juju_application.neutron_api.name
        rabbitmq = juju_application.rabbitmq.name
        vault = juju_application.vault.name
    }
}

module "ceph_cluster" {
    source = "./ceph"
    model = juju_model.ovb.name
    channel = local.ceph.channel
    series = local.series
    config = local.ceph.config
    units = {
        osds = 3
        mons = 3
        rgw = 1
    }
    placement = {
        osds = join(",", local.hyperconverged_juju_ids)
        mons = join(",", [for id in local.hyperconverged_juju_ids: "lxd:${id}"])
        rgw = "lxd:${local.hyperconverged_juju_ids[1]}"
    }
    relation_names = {
        nova = module.nova.application_names.compute
        glance = juju_application.glance.name
    }
}

resource "juju_application" "mysql_innodb_cluster" {
    model = juju_model.ovb.name
    name = "mysql-innodb-cluster" // Needed the name or you get an error about how application- is an invalid application tag
    charm {
        name = "mysql-innodb-cluster"
        channel = local.mysql.channel
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
        channel = local.vault.channel
        series = local.series
    }

    config = local.vault.config

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[0]}"
}

resource "juju_application" "vault_mysql_router" {
    model = juju_model.ovb.name
    name = "vault-mysql-router"
    charm {
        name = "mysql-router"
        channel = local.mysql.channel
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
        channel = local.ovn.channel
        series = local.series
    }

    config = local.ovn.central.config
    units = 3
    placement = join(",", [for id in local.hyperconverged_juju_ids: "lxd:${id}"])
}

resource "juju_application" "neutron_api" {
    model = juju_model.ovb.name
    name = "neutron-api"
    charm {
        name = "neutron-api"
        channel = local.openstack.channel
        series = local.series
    }

    config = local.neutron.api.config

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "neutron_api_plugin_ovn" {
    model = juju_model.ovb.name
    name = "neutron-api-plugin-ovn"
    charm {
        name = "neutron-api-plugin-ovn"
        channel = local.openstack.channel
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
        channel = local.ovn.channel
        series = local.series
    }

    config = local.ovn.chassis.config

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
        name = module.nova.application_names.compute
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
        channel = local.mysql.channel
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
        channel = local.openstack.channel
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
        channel = local.mysql.channel
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
        channel = local.rabbitmq.channel
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

resource "juju_application" "placement" {
    model = juju_model.ovb.name
    name = "placement"
    charm {
        name = "placement"
        channel = local.openstack.channel
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
        channel = local.mysql.channel
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
        name = module.nova.application_names.compute
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
        channel = local.openstack.channel
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
        channel = local.mysql.channel
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
        channel = local.openstack.channel
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
        channel = local.mysql.channel
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
        name = module.nova.application_names.cloud_controller
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
        name = module.nova.application_names.compute
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


resource "juju_application" "cinder" {
    model = juju_model.ovb.name
    name = "cinder"
    charm {
        name = "cinder"
        channel = local.openstack.channel
        series = local.series
    }

    config = local.cinder.config

    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "cinder_mysql_router" {
    model = juju_model.ovb.name
    name = "cinder-mysql-router"
    charm {
        name = "mysql-router"
        channel = local.mysql.channel
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
        name = module.nova.application_names.cloud_controller
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
        channel = local.openstack.channel
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
        name = module.ceph_cluster.application_names.mons
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
        name = module.nova.application_names.compute
        endpoint = "ceph-access"
    }
}

resource "juju_application" "designate" {
    model = juju_model.ovb.name
    name = "designate"
    charm {
        name = "designate"
        channel = local.openstack.channel
        series = local.series
    }
    config = local.designate.config
    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[2]}"
}

resource "juju_application" "designate_bind" {
    model = juju_model.ovb.name
    name = "designate-bind"
    charm {
        name = "designate-bind"
        channel = local.openstack.channel
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
        channel = local.openstack.channel
        series = local.series
    }
    config = local.manila.config
    units = 1
    placement = "lxd:${local.hyperconverged_juju_ids[1]}"
}

resource "juju_application" "manila_generic" {
    model = juju_model.ovb.name
    name = "manila-generic"
    charm {
        name = "manila-generic"
        channel = local.openstack.channel
        series = local.series
    }
    config = local.manila.generic.config
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
        endpoint = "manila-plugin"
    }
}

