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

## Fetch the AZP token

Before running the commands below you will need to fetch the AZP token used between AZP and the CI Agent:

You can do this as follows:

```console

$ AWS_CLI=(docker compose -f docker/docker-compose.yaml run aws)
$ export TF_VAR_azp_token=$(${AWS_CLI[@]} s3 cp s3://cncf-envoy-token/azp_token -)

```

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

For each AMI that you wish to build with packer and the filename as follows:

```console
$ PACKER=(docker compose -f docker/docker-compose.yaml run packer)
$ ${PACKER[@]} build azp-build-arm64.pkr.hcl
...
==> Wait completed after 14 minutes 33 seconds

==> Builds finished. The artifacts of successful builds are:
--> envoy-azp-build-arm64.amazon-ebs.envoy-azp-build-arm64: AMIs were created:
us-east-2: ami-040ef97b32fd740ac
```

Note that this step should be done shortly before updating the infrastructure
using Terraform, since the `azp-dereg-lambda` runs daily and removes all but
the latest AMI. If the infrastructure isn't updated to use the latest AMI, the
lambda may delete an AMI that is in use.

## Building the AWS lambdas

### Node.js dependencies update

The directories
[instances/azp-cleanup-snapshots](instances/azp-cleanup-snapshots) and
[instances/azp-dereg-lambda](instances/azp-dereg-lambda) contain two [AWS
Lambdas](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html) written in
Node.js.

To update run the following

```console
$ NPM_SNAPSHOTS=(docker compose -f docker/docker-compose.yaml run npm_snap)
$ NPM_DEREG=(docker compose -f docker/docker-compose.yaml run npm_dereg)
$ ${NPM_SNAPSHOTS[@]} /workspace/node_modules/.bin/ncu -u
$ ${NPM_DEREG[@]} /workspace/node_modules/.bin/ncu -u
```

### Build lambdas (Node.js zip files)

```console
$ ${NPM_SNAPSHOTS[@]}
$ ${NPM_DEREG[@]}
```

You should see the timestamps updated for the relevant zip files:

```console
$ ls -alh instances/*zip
-rw-r--r-- 1 root root 1.8M Aug  7 21:25 instances/lambda-cleanup.zip
-rw-r--r-- 1 root root 467K Aug  7 21:25 instances/lambda-dereg.zip

```

This will produce two zip files in the [instances](instances) directory that
will be used by Terraform.

## Terraform update

### Test and apply terraform configs

You can refer to [this
documentation](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started)
for details on how to manage AWS infrastructure using Terraform.

Ensure you have the AZP token described above.

Then run the Terraform update step. This should only be done after the PR is
reviewed and approved. In short, execute:

To initialize the local Terraform installation:


```console
$ TERRAFORM=(docker compose -f docker/docker-compose.yaml run terraform)
$ ${TERRAFORM[@]} init

```

To format any Terraform configuration files that were modified.

```console
$ ${TERRAFORM[@]} fmt
```

To test what would be applied use plan:


```console
$ ${TERRAFORM[@]} plan
```

To update the AWS infrastructure applying local changes and switching to the new AMIs.

```console
$ ${TERRAFORM[@]} apply
```
