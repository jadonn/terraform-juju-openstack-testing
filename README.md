# Terraform Juju OpenStack Testing
This repository contains a Terraform plan that deploys OpenStack using the Terraform Juju provider.

**This Terraform plan requires experimental code I added to a fork of the Terraform Juju provider to extend the provider's capabilities. It will not work with the standard Terraform Juju provider.**

If you run this Terraform plan, Terraform will use Juju to provision four machines from the available cloud in Juju and then deploy Ceph, OpenStack, Open Virtual Network (OVN), RabbitMQ, MySQL, and other services that go into a standard OpenStack cloud deployment. **You need to have an existing Juju controller and configuration in place to run this Terraform plan.**