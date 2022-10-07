# Regular maintenance

## Goals

The goals of the regular maintenance process are to update dependencies used by
the CI infrastructure, to pull in bug fixes and improvements and to ensure the
deployed infrastructure doesn't fall too far behind which would result in costly
updates.

## Overview

There are two main portions of the regular maintenance:

1. Update binaries and dependencies used in the AMIs (Amazon Machine Images),
   the disk images used to start the VMs that run the CI infrastructure.
   [Packer](https://www.packer.io/)
   is used to create these images, this step is referred to as the Packer update.
1. Update dependencies used by [Terraform](https://www.terraform.io/) when
   deploying the CI infrastructure. This step is referred to as the Terraform
   update.

## Example update

See https://github.com/envoyproxy/ci-infra/pull/7 for an example of a PR that
performed this update.

## Packer update

All packer configuration files and scripts are in the [ami-build](ami-build/)
directory.

### Update the AZP agent version

Edit the [ami-build/agent-setup.sh](ami-build/agent-setup.sh) file and update
the `AGENT_VERSION` variable to the [latest released
version](https://github.com/microsoft/azure-pipelines-agent/releases) of the AZP
agent.

### Update the Ubuntu OS version

Packer is used to build to AMIs, one for x64 architecture (intel/amd) and one
for the arm64 architecture. The Packer configuration for these two AMIs is in
these files:

- [ami-build/azp-x64.json](ami-build/azp-x64.json)
- [ami-build/azp-arm64.json](ami-build/azp-arm64.json)

Refer to this
[howto](https://learn.hashicorp.com/tutorials/packer/aws-get-started-build-image?in=packer/aws-get-started)
for details on how to build AMIs with Packer. You can also review the
[documentation](https://www.packer.io/plugins/builders/amazon/ebs) for the
Amazon EBS Packer builder.

Edit each of the Packer configuration files and update the `name` under the
`source_ami_filter` to the latest LTS (long-term support) version of the Ubuntu
server image. This
[tutorial](https://ubuntu.com/tutorials/search-and-launch-ubuntu-22-04-in-aws-using-cli#2-search-for-the-right-ami)
outlines how to list images available in AWS.

### Update the Golang version

Golang is used to build https://github.com/buchgr/bazel-remote. Edit
[ami-build/scripts/install-bazel-remote.sh](ami-build/scripts/install-bazel-remote.sh)
and change the link in the `curl` command to download the latest version of
Golang from https://go.dev/dl/.

## Terraform update

TODO(mum4k).
