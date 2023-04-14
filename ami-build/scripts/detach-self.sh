#!/usr/bin/env bash

set -eu -o pipefail

# Check Pre-Reqs, and that we're running on an AWS Instance Seemingly.
if ! hash aws >/dev/null 2>&1 ; then
  echo "Need the AWS Cli in order to set AWS Protection."
  exit 1
fi
if ! hash jq >/dev/null 2>&1 ; then
  echo "Need JQ in order to query credentials."
  exit 2
fi
if [[ ! -f "/sys/devices/virtual/dmi/id/board_asset_tag" ]]; then
  echo "Doesn't seem to be an AWS Instance: [/sys/devices/virtual/dmi/id/board_asset_tag] does not exist".
  exit 3
fi
instance_id=$(< /sys/devices/virtual/dmi/id/board_asset_tag)
if [[ ! "$instance_id" =~ ^i- ]]; then
  echo "Retrieved Instance ID: [$instance_id] does not start with [i-]"
  exit 4
fi

function ensureCredentials() {
    local credentials_json iid_json asg_name aws_access_key secret_access_key session_token expiration region

    if [[ ! -f "/run/aws-metadata/creds.json" ]] || [[ ! -f "/run/aws-metadata/asg-name" ]] || [[ ! -f "/run/aws-metadata/iid.json" ]] || \
           [[ ! -r "/run/aws-metadata/creds.json" ]] || [[ ! -r "/run/aws-metadata/asg-name" ]] || [[ ! -r "/run/aws-metadata/iid.json" ]]; then
        echo "Failed to find Credentials for AWS Instance."
        exit 5
    fi

    credentials_json=$(< /run/aws-metadata/creds.json)
    iid_json=$(< /run/aws-metadata/iid.json)
    asg_name=$(< /run/aws-metadata/asg-name)
    aws_access_key=$(echo -n "$credentials_json" | jq -r .AccessKeyId)
    secret_access_key=$(echo -n "$credentials_json" | jq -r .SecretAccessKey)
    session_token=$(echo -n "$credentials_json" | jq -r .Token)
    expiration=$(echo -n "$credentials_json" | jq -r .Expiration)
    region=$(echo -n "$iid_json" | jq -r .region)

    echo "Fetched Cached Credentials, Expire At: [$expiration]"
    AWS_ACCESS_KEY_ID="$aws_access_key"
    AWS_SECRET_ACCESS_KEY="$secret_access_key"
    AWS_SESSION_TOKEN="$session_token"
    AWS_DEFAULT_REGION="$region"
    CURRENT_ASG_NAME="$asg_name"
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
    export AWS_DEFAULT_REGION
    export CURRENT_ASG_NAME
}

ensureCredentials
aws autoscaling detach-instances --instance-ids "$instance_id" --auto-scaling-group-name "$CURRENT_ASG_NAME" --no-should-decrement-desired-capacity
