#!/usr/bin/env bash

set -e

function terminate {
    # Terminate instances in 1 min
    shutdown -h +1
}
trap terminate EXIT

# Hostname shows in AZP side, use Instance ID Rather than a public ip.
instance_id=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
echo "127.0.1.1 $instance_id" >> /etc/hosts
hostnamectl set-hostname "$instance_id"

azp_token=$(aws s3 cp s3://cncf-envoy-token/azp_token -)

# Configured vars
asg_name="${asg_name:-}"
azp_pool_name="${azp_pool_name:-}"
bazel_cache_bucket="${bazel_cache_bucket:-}"
cache_prefix="${cache_prefix:-}"
instance_profile_arn="${instance_profile_arn:-}"
role_name="${role_name:-}"

if [[ -n "$asg_name" ]]; then
    echo "\`asg_name\` is not set, exiting" >&2
    exit 1
fi
if [[ -n "$azp_pool_name" ]]; then
    echo "\`azp_pool_name\` is not set, exiting" >&2
    exit 1
fi
if [[ -n "$bazel_cache_bucket" ]]; then
    echo "\`bazel_cache_bucket\` is not set, exiting" >&2
    exit 1
fi
if [[ -n "$cache_prefix" ]]; then
    echo "\`cache_prefix\` is not set, exiting" >&2
    exit 1
fi
if [[ -n "$instance_profile_arn" ]]; then
    echo "\`instance_profile_arn\` is not set, exiting" >&2
    exit 1
fi
if [[ -n "$role_name" ]]; then
    echo "\`role_name\` is not set, exiting" >&2
    exit 1
fi

AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
export AWS_DEFAULT_REGION
ASSOCIATION_ID="$(aws ec2 describe-iam-instance-profile-associations --filter=Name=instance-id,Values="${instance_id}" | jq -r '.IamInstanceProfileAssociations[0].AssociationId')"
aws ec2 replace-iam-instance-profile-association \
    --iam-instance-profile Arn="$instance_profile_arn" \
    --association-id "$ASSOCIATION_ID"

# Configure Azure Pipelines Agent, this has to be done at runtime since
# it will show up in the UI once we configure.
sudo -u azure-pipelines /bin/bash -c "cd /srv/azure-pipelines && ./config.sh --unattended --acceptteeeula --url https://dev.azure.com/cncf/ --pool ${azp_pool_name} --token $azp_token"
sudo -u azure-pipelines mkdir /srv/azure-pipelines/_work

# Clear credential cache and verify we're in right role before starting agent
unset azp_token
rm -rf ~/.aws
aws sts get-caller-identity | jq -r '.Arn' | grep -o "/${role_name}/"

# Setup bazel remote cache S3 proxy
echo "
[Unit]
Description=Bazel Remote Cache Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=bazel-remote
ExecStart=/usr/local/bin/bazel-remote --experimental_remote_asset_api --enable_ac_key_instance_mangling --s3.endpoint s3.$AWS_DEFAULT_REGION.amazonaws.com --s3.bucket ${bazel_cache_bucket} --s3.prefix ${cache_prefix} --s3.iam_role_endpoint http://169.254.169.254 --s3.auth_method=iam_role --max_size 500 --dir /dev/shm/bazel-remote-cache

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/bazel-remote.service

systemctl daemon-reload
systemctl enable bazel-remote
systemctl start bazel-remote

# This is a hook to be run when a job starts
run_inotifywait () {
    if inotifywait /srv/azure-pipelines/_work -e CREATE; then
        aws autoscaling detach-instances \
            --instance-ids "$instance_id" \
            --auto-scaling-group-name "${asg_name}" \
            --no-should-decrement-desired-capacity
    fi
}

run_inotifywait &

# Start AZP Agent.
sudo -u azure-pipelines /bin/bash -c 'cd /srv/azure-pipelines && ./run.sh --once'
