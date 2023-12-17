#!/bin/bash -eu

set -o pipefail

. "$(dirname "${BASH_SOURCE[0]}")/common-fun.sh"


_run_inotifywait () {
    # Watch the filesystem for agent activity, and disconnect from
    # the ASG as soon as any happens.
    local instance_id="$1" token_name="$2" asg_name="$3"
    if [[ "$token_name" == "azp_token" ]]; then
        AGENT_USER=$AZP_USER
    else
        AGENT_USER=$GH_USER
    fi
    echo "Waiting for activity on: /srv/$AGENT_USER/_work" >&2
    if inotifywait "/srv/$AGENT_USER/_work" -e CREATE; then
        aws autoscaling detach-instances \
            --instance-ids "$instance_id" \
            --auto-scaling-group-name "${asg_name}" \
            --no-should-decrement-desired-capacity
    fi
}


machine_set_hostname () {
    echo "127.0.1.1 $1" >> /etc/hosts
    hostnamectl set-hostname "$1"
}


aws_reassociate_profile () {
    # Once we have fetched the token we no longer need creds to access that s3
    # but we do need creds to the s3 local storage cache bucket.
    local association_id="$1" instance_profile_arn="$2"
    echo "Reassociating AWS profile" >&2
    aws ec2 replace-iam-instance-profile-association \
        --iam-instance-profile "Arn=${instance_profile_arn}" \
        --association-id "$association_id"
}


aws_asg_detach_on_connect () {
    # Detach from the ASG creating a free slot so another machine will be
    # commissioned
    local instance_id="$1" token_name="$2" asg_name="$3"
    _run_inotifywait "$instance_id" "$token_name" "$asg_name" &
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
    aws ec2 describe-iam-instance-profile-associations \
        --filter=Name=instance-id,Values="${instance_id}" \
        | jq -r '.IamInstanceProfileAssociations[0].AssociationId'
}


aws_get_instance_id () {
    wget -q -O - http://169.254.169.254/latest/meta-data/instance-id
}


aws_get_token () {
    aws s3 cp "s3://cncf-envoy-token/${1}" -
}


aws_get_region () {
    curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region
}


azp_agent_configure () {
    # Run the AZP agent configuration, this would normally happen at build
    # time, but is required here to allow for the dynamic scaling model that is used.
    local pool_name="$1" token="$2"
    echo "Configuring AZP agent" >&2
    _run_as "$AZP_USER" "cd /srv/${AZP_USER} \
                && ./config.sh --unattended \
                               --acceptteeeula \
                               --url https://dev.azure.com/cncf/ \
                               --pool ${pool_name} \
                               --token ${token}"
    _run_as "$AZP_USER" "mkdir /srv/${AZP_USER}/_work"
    echo "AZP agent configured" >&2
}

gh_agent_configure () {
    # Run the Github agent configuration, this would normally happen at build
    # time, but is required here to allow for the dynamic scaling model that is used.
    local instance_id="$1" pool_name="$2" token="$3"
    GH_WORK_DIR="/srv/${GH_USER}/_work"
    CONFIG_ARGS=(
        --unattended
        --url https://github.com/envoyproxy
        --name "${pool_name}-${instance_id}"
        --labels "${pool_name}"
        --runnergroup Envoy
        --disableupdate
        --ephemeral
        --work "${GH_WORK_DIR}")
    echo "Configuring Github agent: ${CONFIG_ARGS[*]}" >&2
    _run_as "$GH_USER" \
                "cd /srv/${GH_USER} \
                && ./config.sh \
                    --pat ${token} \
                    ${CONFIG_ARGS[@]}"
    _run_as "$GH_USER" "mkdir ${GH_WORK_DIR}"
    echo "Github agent configured" >&2
}


configure_bazel_remote () {
    # Set up and start a systemd unit for the bazel local cache.
    local bazel_cache_bucket="$1" cache_prefix="$2" bazel_remote_args
    echo "Configuring bazel-remote (${bazel_cache_bucket}/${cache_prefix})" >&2
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
    echo "Starting bazel-remote" >&2
    systemctl daemon-reload
    systemctl enable bazel-remote
    systemctl start bazel-remote
}


## Start agents
# init
_agent_start_init () {
    local instance_id="$1" \
          token_name="$2" \
          token="$3" \
          pool_name="$4" \
          instance_profile_arn="$6" \
          role_name="$7" \
          aws_association_id
    echo "Starting agent (${instance_id})" >&2

    ## Setup machine
    machine_set_hostname "$instance_id"

    ## Reassociate AWS iam profile
    aws_association_id="$(aws_get_association_id "${instance_id}")"
    aws_reassociate_profile "$aws_association_id" "$instance_profile_arn"

    if [[ "$token_name" == "azp_token" ]]; then
        azp_agent_configure "$pool_name" "$token"
    else
        gh_agent_configure "${instance_id}" "$pool_name" "$token"
    fi

    ## Forget secrets
    aws_clear_credentials "$role_name"
    unset token
}


# finalize
_agent_start_finalize () {
    local instance_id="$1" \
          token_name="$2" \
          asg_name="$4"
    echo "Finalizing agent (${instance_id})" >&2
    ## Start agent listening
    aws_asg_detach_on_connect "$instance_id" "$token_name" "$asg_name"
    if [[ "$token_name" == "azp_token" ]]; then
        echo "Running AZP agent (${asg_name}/${instance_id})" >&2
        _run_as "$AZP_USER" "cd /srv/${AZP_USER} && ./run.sh --once"
        echo "AZP agent ran" >&2
    else
        echo "Running Github agent (${asg_name}/${instance_id})" >&2
        _run_as "$GH_USER" "cd /srv/${GH_USER} && ./run.sh"
        echo "Github agent ran" >&2
    fi
}


agent_start_build () {
    # This should be called with the following args:
    #  pool_name
    #  asg_name
    #  instance_profile_arn
    #  role_name
    #  bazel_cache_bucket
    #  cache_prefix
    #  token_name
    local bazel_cache_bucket="$5" \
          cache_prefix="$6" \
          token_name="$7" \
          instance_id token
    echo "Starting cached CI (${AWS_DEFAULT_REGION})" >&2

    ## Get token, this must be done before reassociation
    token="$(aws_get_token "${token_name}")"
    instance_id="$(aws_get_instance_id)"

    _agent_start_init "$instance_id" "$token_name" "$token" "$@"
    unset token

    # Start bazel remote
    configure_bazel_remote "$bazel_cache_bucket" "$cache_prefix"
    start_bazel_remote

    _agent_start_finalize "$instance_id" "$token_name" "$@"
}


agent_start_minimal () {
    # This should be called with the following args:
    #  pool_name
    #  asg_name
    #  instance_profile_arn
    #  role_name
    #  token_name
    local instance_id \
          token \
          token_name="$5"
    echo "Starting CI (${AWS_DEFAULT_REGION})" >&2
    instance_id="$(aws_get_instance_id)"
    ## Get token, this must be done before reassociation
    token="$(aws_get_token "${token_name}")"
    _agent_start_init "$instance_id" "$token_name" "$token" "$@"
    unset token
    _agent_start_finalize "$instance_id" "$token_name" "$@"
}
