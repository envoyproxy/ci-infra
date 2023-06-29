# Defines a Packer template that builds an AMI image of a minimal x64 VM that runs
# the AZP Agent.

source "amazon-ebs" "envoy-azp-build-x64" {
  ami_name = "envoy-azp-build-x64-{{timestamp}}"
  instance_type = "r5.large"
  region = "us-east-2"
  security_group_ids = ["sg-030a7a75a086f208c"]

  source_ami_filter {
    filters = {
      # Found with:
      # aws ec2 describe-images --owners 'aws-marketplace' --output json --region us-east-2 --filters "Name=product-code,Values=4s6b2r2vfe46kyul508kf459f"
      name = "ubuntu-minimal/images/hvm-ssd/ubuntu-jammy-22.04-amd64-minimal-*"
      root-device-type = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    # TODO: figure out why setting this (incorrectly) worked and uncomment
    owners = ["679593333241"]
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
    "Project" : "Envoy",
    "AmiType" : "envoy-azp-build-x64"
  }
}

build {
  name = "envoy-azp-build-x64"
  sources = [
    "source.amazon-ebs.envoy-azp-build-x64"
  ]

  provisioner "file" {
    source = "scripts"
    destination = "/home/ubuntu/scripts"
  }

  provisioner "shell" {
    script = "agent-setup-build.sh"
    execute_command = "{{.Vars}} sudo -S -E bash -eu '{{.Path}}'"
  }
}
