terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4.0"
    }
  }
}

# Variables needed to authenticate with the NETWAYS Cloud
variable "ssh_pub_key" {}
variable "project_name" {}
variable "password" {}

# OpenStack provider configuration
provider "openstack" {
    auth_url     = "https://cloud.netways.de:5000/v3"
    tenant_name = var.project_name
    user_name    = var.project_name
    password     = var.password
}

# Lookup of the project's private network needed for creating the network port below
data "openstack_networking_network_v2" "private" {
  name = var.project_name
}

# Security group + rules for the VM
resource "openstack_networking_secgroup_v2" "http_https" {
  name        = "sg-http-https"
  description = "Allow inbound HTTP (80) and HTTPS (443) traffic"
}

resource "openstack_networking_secgroup_rule_v2" "allow_http" {
  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 80
  port_range_max   = 80
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.http_https.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_https" {
  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 443
  port_range_max   = 443
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.http_https.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  direction        = "ingress"
  ethertype        = "IPv4"
  protocol         = "tcp"
  port_range_min   = 22
  port_range_max   = 22
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.http_https.id
}

# SSH key for connecting to the VM
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "tf-keypair"
  public_key = var.ssh_pub_key
}

# Network port for the VM's public IP
resource "openstack_networking_port_v2" "vm_port" {
  name               = "vm-port"
  network_id         = data.openstack_networking_network_v2.private.id
  admin_state_up     = true
  security_group_ids = [openstack_networking_secgroup_v2.http_https.id]
}

# VM definition and public IP assignment
resource "openstack_compute_instance_v2" "docker_host" {
  name        = "docker-host"
  image_name  = "Ubuntu Noble 24.04 LTS"
  flavor_name = "s1.small"
  key_pair    = openstack_compute_keypair_v2.keypair.name

  # Attach the previously created port (instead of letting Nova create its own)
  network {
    port = openstack_networking_port_v2.vm_port.id
  }
}

resource "openstack_networking_floatingip_v2" "fip" {
  pool = "public-network"
}

resource "openstack_networking_floatingip_associate_v2" "port_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  port_id     = openstack_networking_port_v2.vm_port.id
}

# Outputs 
output "instance_id" {
  description = "ID of the created VM."
  value       = openstack_compute_instance_v2.docker_host.id
}

output "private_ip" {
  description = "Fixed/private IP address assigned to the VM."
  value       = openstack_networking_port_v2.vm_port.all_fixed_ips[0]
}

output "floating_ip" {
  description = "Public IP that can be used to reach the VM."
  value       = openstack_networking_floatingip_v2.fip.address
}
