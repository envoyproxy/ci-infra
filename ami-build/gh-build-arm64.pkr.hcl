# Defines a Packer template that builds an AMI image of a minimal arm64 VM that runs
# the Github Agent.

source "amazon-ebs" "envoy-gh-build-arm64" {
  ami_name = "envoy-gh-build-arm64-{{timestamp}}"
  instance_type = "m6g.large"
  region = "us-east-2"
  security_group_ids = ["sg-030a7a75a086f208c"]

  source_ami_filter {
    filters = {
      name = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-*"
      root-device-type = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
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
    "AmiType" : "envoy-gh-build-arm64"
  }
}

build {
  name = "envoy-gh-build-arm64"
  sources = [
    "source.amazon-ebs.envoy-gh-build-arm64"
  ]

  provisioner "file" {
    source = "scripts"
    destination = "/home/ubuntu/scripts"
  }

  provisioner "shell" {
    script = "gh-agent-setup-cached-build.sh"
    execute_command = "{{.Vars}} sudo -S -E bash -eu '{{.Path}}'"
  }
}
