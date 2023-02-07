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