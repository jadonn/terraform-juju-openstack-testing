# Terraform Juju OpenStack Testing
This repository contains a Terraform plan that deploys OpenStack using the Terraform Juju provider.

If you run this Terraform plan, Terraform will use Juju to provision machines from the available cloud in Juju and then deploy Ceph, OpenStack, Open Virtual Network (OVN), RabbitMQ, MySQL, and other services that go into a standard OpenStack cloud deployment. **You need to have an existing Juju controller and configuration in place to run this Terraform plan.**

## How I use this plan
I have a single node MAAS instance running with four virtual machines registered as machines MAAS can deploy. The virtual machines are OpenStack virtual machine instances. I use [the OpenStack VirtualBMC project](https://opendev.org/openstack/virtualbmc) to enable managing the virtual machine instances using IPMI similar to how physical machines with baseboard management controllers (BMCs) would be managed.

One virtual machine is deployed as a Juju controller with the MAAS server added as a MAAS cloud in Juju.

The other three virtual machines are used as hosts for deploying OpenStack, Ceph, and OVN in a hyperconverged configuration. That is, each host has compute services, control plane services, and storage services running alongside one another on the same machine. I use this configuration for testing and evaluation purposes of OpenStack.

## Notes on virtual baremetal infrastructure
The Terraform plan in the `infra` directory can automate much of the provisioning and configuration of OpenStack virtual machine instances. I use it to automate almost the entire deployment of the virtual machine instances. You do have to have your own MAAS server running, and you currently have to set up the network bridge configuration in MAAS for the network interfaces of the virtual machines after they are registered in MAAS.

### Use the iPXE boot image from the OpenStack Virtual Baremetal project
[The OpenStack Virtual Baremetal project](https://opendev.org/openstack/openstack-virtual-baremetal) has configuration that you can use to build an iPXE boot image for your OpenStack instances.

This image makes the OpenStack instances support PXE booting and registering with MAAS.

#### Rebuild your OpenStack instances after releasing them
If you are using the iPXE image from the OpenStack Virtual Baremetal project, you must rebuild your instances after you have released them in MAAS. Assuming the iPXE image is uploaded to OpenStack under the name `ipxe-boot`, you can rebuild an instance with the following command:
```
openstack server rebuild YOUR_INSTANCE_NAME --image ipxe-boot
```

This will rebuild the instance and return it to the original configuration it had when the instance was provisioned.