# Infrastructure for Salvo.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.61"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

# Pool of Salvo Control VMs.
module "salvo-azp-agent-vm-x64-pool" {
  source = "./azp-salvo-asg"

  salvo_vpc                       = aws_vpc.salvo-infra-vpc
  salvo_control_vm_subnet         = aws_subnet.salvo-infra-control-vm-subnet
  salvo_control_vm_security_group = aws_security_group.salvo-infra-allow-ssh-from-world-security-group
  ami_prefix                      = "salvo-azp-agent-vm-x64"
  aws_account_id                  = "457956385456"
  azp_pool_name                   = "salvo-control"
  azp_token                       = var.azp_token
  disk_size_gb                    = 10
  idle_instances_count            = 0
  instance_types                  = ["t3.nano"]

  providers = {
    aws = aws
  }
}
