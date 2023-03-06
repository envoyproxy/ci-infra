# Envoy CI Infra #

This repo contains configs and scripts that used to provisioning CI infrastructure
for Envoy.


# Self-hosted AZP Agents #

This contains all the code necessary for creating our Self-hosted AZP Agents.
Right now this is done by creating AMI's with [Packer](https://www.packer.io/),
and then standing up all of the Infrastructure with
[Terraform](https://www.terraform.io/).

The general idea is:

  - AMIs are built with all necessary tooling, for Linux this includes:
    - [`azure-pipelines-agent`](https://github.com/microsoft/azure-pipelines-agent),
      `awscli` and `jq` for agent setup.
    - `bazelisk`
    - `docker`
    - `skopeo`
    - `expect` for example testing.
    - [`bazel-remote`](https://github.com/buchgr/bazel-remote) for local S3 bazel cache proxy.

  - AMIs are referenced by a launch template for an ASG.

  - The ASG stands up a "minimum" number of idle instances to always be online to
    work builds.

  - When an agent started running a job, it detach itself from the ASG without
    reducing desired number. A new idle runner will be spawn by the ASG.

  - When an agent finishes the job, it terminates itself.

  - A Lambda watches the EC2 CloudWatch instance termination event,
   and properly deregisters the agent from AZP.

# Regulare maintenance

The regular maintenance process is documented in
[MAINTENANCE.md](MAINTENANCE.md).
