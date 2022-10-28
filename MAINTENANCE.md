# Regular maintenance

## Goals

The goals of the regular maintenance process are to update dependencies used by
the CI infrastructure, to pull in bug fixes and improvements and to ensure the
deployed infrastructure doesn't fall too far behind which would result in costly
updates.

## Overview

These are the steps taken when performing the regular maintenance:

1. Update binaries and dependencies used in the AMIs (Amazon Machine Images),
   the disk images used to start the VMs that run the CI infrastructure.
   [Packer](https://www.packer.io/)
   is used to create these images, this step is referred to as the Packer update.
1. Update Node.js dependencies used by AWS Lambdas that perform cleanup tasks
   like AMI de-registration.
1. Update the infrastructure using [Terraform](https://www.terraform.io/), so
   that the VMs use the newly built images.

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

Packer is used to build two AMIs, one for x64 architecture (intel/amd) and one
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

### Update the bazel-remote version

Edit the
[ami-build/scripts/install-bazel-remote.sh](ami-build/scripts/install-bazel-remote.sh)
file and modify the target of the `wget` command to the latest released
`bazel-remote` version from https://github.com/buchgr/bazel-remote/tags.

### Build updated AMIs with Packer

Once the updates are performed, build and push the new AMIs to AWS by running:

- `packer build azp-x64.json`.
- `packer build azp-arm64.json`.

Note that this step should be done shortly before updating the infrastructure
using Terraform, since the `azp-dereg-lambda` runs daily and removes all but
the latest AMI. If the infrastructure isn't updated to use the latest AMI, the
lambda may delete an AMI that is in use.

## Node.js dependencies update

The directories
[instances/azp-cleanup-snapshots](instances/azp-cleanup-snapshots) and
[instances/azp-dereg-lambda](instances/azp-dereg-lambda) contain two [AWS
Lambdas](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) written in
Node.js.

To update the dependencies, first make sure you have
[npm-check-updates](https://www.npmjs.com/package/npm-check-updates) installed.

Then go to each of the two directories and run `ncu -u`.

## Terraform update

You can refer to [this
documentation](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started)
for details on how to manage AWS infrastructure using Terraform.

The Terraform update step should only be done after the PR is reviewed and
approved. In short, execute:

- `terraform init` - to initialize the local Terraform installation.
- `terraform fmt` - to format any Terraform configuration files that were
  modified.
- `terraform apply` - to update the AWS infrastructure applying local changes
  and switching to the new AMIs.
