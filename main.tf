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
    controller_addresses = "10.0.0.60:17070"
    username = "tf-ovb"
    password = "tf-ovb"
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
}

resource "juju_machine" "ovb_two" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-two"
}

resource "juju_machine" "ovb_three" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-three"
}

resource "juju_machine" "ovb_four" {
    model = juju_model.ovb.name
    series = "jammy"
    name = "ovb-four"
}

resource "juju_application" "ceph_osd" {

    model = juju_model.ovb.name

    charm {

        name = "ceph-osd"
        channel = "quincy/stable"
        series = "focal"

    }

    units = 4

    config = {

        osd-devices = "/dev/vdb"
        source = "distro"

    }

}

resource "juju_application" "nova-compute" {

    model = juju_model.ovb.name

    charm {

        name = "nova-compute"
        channel = "yoga/stable"
        series = "focal"

    }

    units = 3

    config {

        config-flags = "default_ephemeral_format=ext4"
        enable-live-migration = "true"
        enable-resize = "true"
        migration-auth-type = "ssh"
        virt-type = "qemu"
        openstack-origin = "distro"

    }

}

resource "juju_application" "mysql-innodb-cluster" {

    model = juju_model.ovb.name

    charm {

        name = "mysql-innodb-cluster"
        channel = "8.0/stable"
        series = "focal"

    }

    units = 3
    
}

resource "juju_application" "vault" {

    charm {

        name = "vault"
        channel = "1.7/stable"
        series = "focal"

    }

}

resource "juju_application" "vault-mysql-router" {

    charm {

        name = "vault-mysql-router"

    }

}

