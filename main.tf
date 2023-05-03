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
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[0]}"
    }
}

locals {
    ovn = {
        channel = "22.03/stable"
        central = {
            config = {
                source = "distro"
            }
            units = 3
            placement = join(",", [for id in local.hyperconverged_juju_ids: "lxd:${id}"])
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
            units = 1
            placement = "lxd:${local.hyperconverged_juju_ids[1]}"
        }
    }
}

locals {
    keystone = {
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[2]}"
    }
}

locals {
    placement = {
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[2]}"
    }
}

locals {
    dashboard = {
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[0]}"
    }
}

locals {
    glance = {
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[1]}"
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
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[2]}"
    }
}

locals {
    designate = {
        config = {
            nameservers = "ns1.not-a-real-domain.com. ns2.not-a-real-domain.com."
        }
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[2]}"
    }
}

locals {
    memcached = {
        channel = "latest/stable"
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[0]}"
    }
}

locals {
    manila = {
        config = {
            default-share-backend = "generic"
        }
        units = 1
        placement = "lxd:${local.hyperconverged_juju_ids[1]}"
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
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        neutron_api = module.neutron_ovn.application_names.neutron_api
        rabbitmq = juju_application.rabbitmq.name
        vault = module.vault.application_names.vault
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
        glance = module.glance.application_names.glance
    }
}

module "vault" {
    source = "./vault"
    model = juju_model.ovb.name
    channel = local.vault.channel
    series = local.series
    mysql = {
        channel = local.mysql.channel
    }
    config = {
        vault = local.vault.config
    }
    units = {
        vault = local.vault.units
    }
    placement = {
        vault = local.vault.placement
    }
    relation_names = {
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
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

module "neutron_ovn" {
    source = "./neutron-ovn"
    model = juju_model.ovb.name
    channel = {
        mysql = local.mysql.channel
        openstack = local.openstack.channel
        ovn = local.ovn.channel
    }
    series = local.series
    config = {
        central = local.ovn.central.config
        chassis = local.ovn.chassis.config
        neutron_api = local.neutron.api.config
    }
    units = {
        central = local.ovn.central.units
        neutron_api = local.neutron.api.units
    }
    placement = {
        central = local.ovn.central.placement
        neutron_api = local.neutron.api.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        nova_compute = module.nova.application_names.compute
        rabbitmq = juju_application.rabbitmq.name
        vault = module.vault.application_names.vault
    }
}

module "keystone" {
    source = "./keystone"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        mysql = local.mysql.channel
    }
    series = local.series
    units = {
        keystone = local.keystone.units
    }
    placement = {
        keystone = local.keystone.placement
    }
    relation_names = {
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        vault = module.vault.application_names.vault
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

module "placement" {
    source = "./placement"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        mysql = local.mysql.channel
    }
    series = local.series
    units = {
        placement = local.placement.units
    }
    placement = {
        placement = local.placement.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        nova_cloud_controller = module.nova.application_names.cloud_controller
        vault = module.vault.application_names.vault
    }
}

module "dashboard" {
    source = "./dashboard"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        mysql = local.mysql.channel
    }
    series = local.series
    units = {
        dashboard = local.dashboard.units
    }
    placement = {
        dashboard = local.dashboard.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        vault = module.vault.application_names.vault
    }
}

module "glance" {
    source = "./glance"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        mysql = local.mysql.channel
    }
    series = local.series
    units = {
        glance = local.glance.units
    }
    placement = {
        glance = local.glance.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        nova_cloud_controller = module.nova.application_names.cloud_controller
        nova_compute = module.nova.application_names.compute
        vault = module.vault.application_names.vault
    }
}

module "cinder" {
    source = "./cinder"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        mysql = local.mysql.channel
    }
    series = local.series
    config = {
        cinder = local.cinder.config
    }
    units = {
        cinder = local.cinder.units
    }
    placement = {
        cinder = local.cinder.placement
    }
    relation_names = {
        ceph_mons = module.ceph_cluster.application_names.mons
        glance = module.glance.application_names.glance
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        nova_compute = module.nova.application_names.compute
        nova_cloud_controller = module.nova.application_names.cloud_controller
        rabbitmq = juju_application.rabbitmq.name
        vault = module.vault.application_names.vault
    }
}

module "designate" {
    source = "./designate"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
        memcached = local.memcached.channel
        mysql = local.mysql.channel
    }
    series = local.series
    config = {
        designate = local.designate.config
    }
    units = {
        designate = local.designate.units
        memcached = local.memcached.units
    }
    placement = {
        designate = local.designate.placement
        memcached = local.memcached.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        neutron_api = module.neutron_ovn.application_names.neutron_api
        rabbitmq = juju_application.rabbitmq
    }
}

module "manila" {
    source = "./manila"
    model = juju_model.ovb.name
    channel = {
        openstack = local.openstack.channel
    }
    series = local.series
    config = {
        manila = local.manila.config
        manila_generic = local.manila.generic.config
    }
    units = {
        manila = local.manila.units
    }
    placement = {
        manila = local.manila.placement
    }
    relation_names = {
        keystone = module.keystone.application_names.keystone
        mysql_innodb_cluster = juju_application.mysql_innodb_cluster.name
        rabbitmq = juju_application.rabbitmq.name
    }
}