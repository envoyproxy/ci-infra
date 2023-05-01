# Defines a Packer template that builds an AMI image of a Salvo VM that runs
# the AZP Agent.

packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# See https://developer.hashicorp.com/packer/plugins/builders/amazon/ebs.
source "amazon-ebs" "salvo-azp-agent-vm-x64" {
  ami_name                    = "salvo-azp-agent-vm-x64-{{timestamp}}"
  instance_type               = "m6i.large"
  region                      = "us-west-1"
  vpc_id                      = "vpc-0b1493d6a970c32bd" # salvo-infra-vpc
  associate_public_ip_address = true
  subnet_id                   = "subnet-0d07ecf83aad87c08" # salvo-infra-packer-subnet

  source_ami_filter {
    filters = {
      # Found with:
      # aws ec2 describe-images --owners 'aws-marketplace' --output json --region us-east-2 --filters "Name=product-code,Values=4s6b2r2vfe46kyul508kf459f"
      name                = "ubuntu-minimal/images/hvm-ssd/ubuntu-jammy-22.04-amd64-minimal-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["679593333241"]
  }
  encrypt_boot = true
  ssh_username = "ubuntu"

  run_tags = {
    "Project" : "Packer"
  }
  run_volume_tags = {
    "Project" : "Packer"
  }
  tags = {
    "Project" : "Salvo",
    "AmiType" : "salvo-azp-agent-vm-x64"
  }
}

build {
  name = "salvo-azp-agent-vm-x64"
  sources = [
    "source.amazon-ebs.salvo-azp-agent-vm-x64"
  ]

  provisioner "file" {
    source = "../../ami-build/scripts/"
    destination = "/home/ubuntu/scripts"
  }

  # See https://developer.hashicorp.com/packer/docs/provisioners/shell.
  provisioner "shell" {
    script          = "salvo-azp-agent-vm.sh"
    execute_command = "{{.Vars}} sudo -S -E sh -eux '{{.Path}}'"
  }
}
