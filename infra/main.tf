terraform {
    required_providers {
        juju = {
          version = "~> 0.0.1"
          source  = "github.com/jadonn/juju"
        }
        openstack = {
            source = "terraform-provider-openstack/openstack"
            version = "~> 1.48.0"
        }
    }
}

provider "juju" {}

provider "openstack" {}

variable "MAAS_API_KEY" {}

variable "MAAS_API_URL" {}

variable "IPMI_USER" {}

variable "IPMI_PASSWORD" {}

locals {
    baremetal_network_name = "baremetal"
    ipxe_image_name = "ipxe-boot"
}

locals {
  control_plane_machines_count = 3
  control_plane_flavor = "m1.small"
  control_plane_image = local.ipxe_image_name
}

locals {
    storage_machines_count = 4
    storage_machines_flavor = "m1.medium"
    storage_machines_image = local.ipxe_image_name
}

locals {
    compute_machines_count = 3
    compute_machines_flavor = "m1.xxlarge"
    compute_machines_image = local.ipxe_image_name
}

resource "openstack_compute_instance_v2" "bmc_terraform" {
    name = "bmc_terraform"
    image_name = "ubuntu-jammy-22.04-amd64-server"
    flavor_name = "m1.small"
    network {
        name = "jadonn_admin_net"
    }
    key_pair = "maas"

    connection {
        type = "ssh"
        user = "ubuntu"
        host = openstack_compute_instance_v2.bmc_terraform.access_ip_v4
        private_key = file("/home/ubuntu/.ssh/id_rsa")
    }

    provisioner "remote-exec" {
        inline = [
            "sudo apt-get update",
            "sudo apt-get install python3-pip -y -q",
            "sudo ln -s /usr/bin/python3 /usr/bin/python",
            "git clone https://opendev.org/openstack/openstack-virtual-baremetal.git",
            "cd openstack-virtual-baremetal/",
            "python3 -m pip install -r requirements.txt",
            "echo 'export PATH=\"/home/ubuntu/.local.bin:$PATH\"' >> /home/ubuntu/.bashrc"
        ]
    }

    provisioner "file" {
        source = "/home/ubuntu/novarc"
        destination = "/home/ubuntu/novarc"
    }
}

resource "openstack_compute_instance_v2" "control_plane" {
    count = local.control_plane_machines_count
    name = "baremetal_control_plane_${count.index}"
    image_name = local.control_plane_image
    flavor_name = local.control_plane_flavor
    network {
        name = local.baremetal_network_name
    }
    lifecycle {
        ignore_changes = [
            power_state,
        ]
    }
}

resource "openstack_compute_instance_v2" "storage" {
    count = local.storage_machines_count
    name = "baremetal_storage_${count.index}"
    image_name = local.storage_machines_image
    flavor_name = local.storage_machines_flavor
    network {
        name = local.baremetal_network_name
    }
    lifecycle {
        ignore_changes = [
            power_state,
        ]
    }
}

resource "openstack_compute_instance_v2" "compute" {
    count = local.compute_machines_count
    name = "baremetal_compute_${count.index}"
    image_name = local.compute_machines_image
    flavor_name = local.compute_machines_flavor
    network {
        name = local.baremetal_network_name
    }
    lifecycle {
        ignore_changes = [
            power_state,
        ]
    }
}

locals {
    machines = {for index, value in concat(openstack_compute_instance_v2.control_plane, openstack_compute_instance_v2.storage, openstack_compute_instance_v2.compute): index => value}
}

resource "null_resource" "configure_vbmc" {
    for_each = local.machines

    connection {
        type = "ssh"
        user = "ubuntu"
        host = openstack_compute_instance_v2.bmc_terraform.access_ip_v4
        private_key = file("/home/ubuntu/.ssh/id_rsa")
    }

    provisioner "file" {
        content = <<-EOT
        [Unit]
        Description="OpenStack Virtual BMC service for OpenStack VM ${each.value.name}
        After=network.target

        [Service]
        Type=simple
        Restart=on-failure
        RestartSec=10
        KillSignal=SIGINT
        User=ubuntu
        Group=ubuntu
        WorkingDirectory=/home/ubuntu/openstack-virtual-baremetal
        EnvironmentFile=/home/ubuntu/novarc
        ExecStart=/home/ubuntu/openstack-virtual-baremetal/bin/openstackbmc --port ${sum([6000, each.key])} --instance ${each.value.id}
        EOT
        destination = "/home/ubuntu/bmc-${replace(each.value.name, "_", "-")}.service"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo cp /home/ubuntu/bmc-${replace(each.value.name, "_", "-")}.service /etc/systemd/system/bmc-${replace(each.value.name, "_", "-")}.service",
            "sudo systemctl daemon-reload",
            "sudo systemctl start bmc-${replace(each.value.name, "_", "-")}.service"
        ]
    }
}

resource "null_resource" "config_maas" {
    for_each = local.machines
    provisioner "local-exec" {
        command = "maas login admin ${var.MAAS_API_URL} ${var.MAAS_API_KEY}"
    }

    provisioner "local-exec" {
        command = "maas admin machine update $(maas admin machines read mac_address=${each.value.network[0].mac}) hostname=${each.value.name} power_type=ipmi power_parameters_power_address=${openstack_compute_instance_v2.bmc_terraform.access_ip_v4}:${sum([6000, each.key])} power_parameters_power_user=${var.IPMI_USER} power_parameters_power_pass=${var.IPMI_PASSWORD}"
    }
}
