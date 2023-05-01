# This file contains the input variables for this Terraform module.

# The VPC used by Salvo.
variable "salvo_vpc" {
  type = object({ id = string })
}

# The subnet in which all Salvo Control VMs should be started.
# Control VMs are VMs that run the AZP agent and the Salvo controller and
# instrument execution of the Salvo pipeline.
variable "salvo_control_vm_subnet" {
  type = object({ id = string })
}

# The security group to apply to all the Salvo Control VM instances.
variable "salvo_control_vm_security_group" {
  type = object({ id = string })
}

# Prefix match on the AMIs that should be used for the control VMs.
variable "ami_prefix" { type = string }

# The account ID under which the resources are deployed.
variable "aws_account_id" { type = string }

# The name of the AZP pool that receives jobs fro the Salvo control VMs.
variable "azp_pool_name" { type = string }

# Token used when the AZP agent on the control VM registers with the AZP pool.
variable "azp_token" { type = string }

# The disk size of the Salvo control VMs in GB.
variable "disk_size_gb" { type = number }

# The number of on-demand instances to keep in the pool.
# These are more available, but also more expensive when compared to the spot
# instances.
variable "on_demand_instances_count" {
  type    = number
  default = 0
}

# The number of Salvo control VM instances to keep active in the auto scaling
# group.
variable "idle_instances_count" { type = number }

# The instance types to use in the pool.
variable "instance_types" { type = list(string) }
