#!/bin/bash -eu

set -o pipefail


AZP_USER=azure-pipelines


_run_as_azp () {
    sudo -u "$AZP_USER" /bin/bash -c "$1"
}


_run_inotifywait () {
    # Watch the filesystem for agent activity, and disconnect from
    # the ASG as soon as any happens.
    local instance_id="$1" asg_name="$2"
    if inotifywait "/srv/$AZP_USER/_work" -e CREATE; then
        aws autoscaling detach-instances \
            --instance-ids "$instance_id" \
            --auto-scaling-group-name "${asg_name}" \
            --no-should-decrement-desired-capacity
    fi
}


machine_set_hostname () {
    # Hostname shows in AZP side, use Instance ID Rather than a public ip.
    echo "127.0.1.1 $1" >> /etc/hosts
    hostnamectl set-hostname "$1"
}


aws_reassociate_profile () {
    # Once we have fetched the AZP token we no longer need creds to access that s3
    # but we do need creds to the s3 local storage cache bucket.
    local association_id="$1" instance_profile_arn="$2"
    aws ec2 replace-iam-instance-profile-association \
        --iam-instance-profile "Arn=${instance_profile_arn}" \
        --association-id "$association_id"
}


aws_asg_detach_on_connect () {
    # Detach from the ASG creating a free slot so another machine will be
    # commissioned
    local instance_id="$1" asg_name="$2"
    _run_inotifywait "$instance_id" "$asg_name" &
}


aws_clear_credentials () {
    # Clear AWS credentials and cache, and verify we're in right role before
    # starting agent
    local role_name="$1"
    rm -rf ~/.aws
    aws sts get-caller-identity | jq -r '.Arn' | grep -o "/${role_name}/"
}


aws_get_association_id () {
    local association_id instance_id="$1"
    association_id="$(\
        aws ec2 describe-iam-instance-profile-associations \
            --filter=Name=instance-id,Values="${instance_id}" \
            | jq -r '.IamInstanceProfileAssociations[0].AssociationId')"
    echo -n "$association_id"
}


aws_get_azp_token () {
    local azp_token
    azp_token="$(aws s3 cp s3://cncf-envoy-token/azp_token -)"
    echo -n "$azp_token"
}


aws_get_region () {
    local region
    region="$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)"
    echo -n "$region"
}


azp_agent_configure () {
    # Run the AZP agent configuration, this would normally happen at build
    # time, but is required here to allow for the dynamic scaling model that is used.
    local azp_pool_name="$1" azp_token="$2"
    _run_as_azp "cd /srv/${AZP_USER} \
                && ./config.sh --unattended \
                               --acceptteeeula \
                               --url https://dev.azure.com/cncf/ \
                               --pool ${azp_pool_name} \
                               --token ${azp_token}"
    _run_as_azp "mkdir /srv/${AZP_USER}/_work"
}


azp_agent_start () {
    _run_as_azp "cd /srv/${AZP_USER} && ./run.sh --once"
}


azp_get_instance_id () {
    local instance_id
    instance_id="$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)"
    echo -n "$instance_id"
}


configure_bazel_remote () {
    # Set up and start a systemd unit for the bazel local cache.
    local bazel_cache_bucket="$1" cache_prefix="$2" bazel_remote_args
    bazel_remote_args=(
        --experimental_remote_asset_api
        --enable_ac_key_instance_mangling
        --s3.endpoint "s3.${AWS_DEFAULT_REGION}.amazonaws.com"
        --s3.bucket "${bazel_cache_bucket}"
        --s3.prefix "${cache_prefix}"
        --s3.iam_role_endpoint http://169.254.169.254
        --s3.auth_method=iam_role
        --max_size 500
        --dir /dev/shm/bazel-remote-cache)
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
ExecStart=/usr/local/bin/bazel-remote ${bazel_remote_args[*]}

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/bazel-remote.service
}


start_bazel_remote () {
    systemctl daemon-reload
    systemctl enable bazel-remote
    systemctl start bazel-remote
}


## Start agents
# init
_agent_start_init () {
    local instance_id="$1" \
          azp_pool_name="$2" \
          instance_profile_arn="$4" \
          role_name="$5" \
          azp_token aws_association_id

    ## Setup machine
    machine_set_hostname "$instance_id"

    ## Get azp token, this must be done before reassociation
    azp_token="$(aws_get_azp_token)"

    ## Reassociate AWS iam profile
    aws_association_id="$(aws_get_association_id "${instance_id}")"
    aws_reassociate_profile "$aws_association_id" "$instance_profile_arn"

    ## Configure AZP agent
    # This has to be done at runtime since it will show up in the UI once we configure.
    azp_agent_configure "$azp_pool_name" "$azp_token"

    ## Forget secrets
    aws_clear_credentials "$role_name"
    unset azp_token
}


# finalize
_agent_start_finalize () {
    local instance_id="$1" \
          asg_name="$3"
    ## Start agent listening
    aws_asg_detach_on_connect "$instance_id" "$asg_name"
    azp_agent_start
}


agent_start_build () {
    # This should be called with the following args:
    #  azp_pool_name
    #  asg_name
    #  instance_profile_arn
    #  role_name
    #  bazel_cache_bucket
    #  cache_prefix
    local bazel_cache_bucket="$5" \
          cache_prefix="$6" \
          instance_id

    instance_id="$(azp_get_instance_id)"
    _agent_start_init "$instance_id" "$@"

    # Start bazel remote
    configure_bazel_remote "$bazel_cache_bucket" "$cache_prefix"
    start_bazel_remote

    _agent_start_finalize "$instance_id" "$@"
}


agent_start_minimal () {
    # This should be called with the following args:
    #  azp_pool_name
    #  asg_name
    #  instance_profile_arn
    #  role_name
    local instance_id
    instance_id="$(azp_get_instance_id)"
    _agent_start_init "$instance_id" "$@"
    _agent_start_finalize "$instance_id" "$@"
}
