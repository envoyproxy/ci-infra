terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

## x64

module "x64-large-build-pool" {
  source = "./cached-build-asg"

  ami_prefix           = "envoy-azp-build-x64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-x64-large"
  token                = var.azp_token
  disk_size_gb         = 2000
  idle_instances_count = 1
  instance_types       = ["r5a.8xlarge", "r5.8xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-x64"
  token_name           = "azp_token"

  providers = {
    aws = aws
  }
}

module "small-x64-build-pool" {
  source = "./small-build-asg"

  ami_prefix           = "envoy-azp-build-x64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-x64-small"
  token                = var.azp_token
  idle_instances_count = 2
  instance_types       = ["r6a.xlarge", "r6i.xlarge", "m4.xlarge", "t3.xlarge"]
  token_name           = "azp_token"

  providers = {
    aws = aws
  }
}

## arm64

module "arm-build-pool" {
  source = "./cached-build-asg"

  ami_prefix           = "envoy-azp-build-arm64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-arm-large"
  token                = var.azp_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.8xlarge", "m6g.16xlarge", "m6gd.8xlarge", "m6gd.16xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"
  token_name           = "azp_token"

  providers = {
    aws = aws
  }
}

module "small-arm-build-pool" {
  source = "./cached-build-asg"

  ami_prefix           = "envoy-azp-build-arm64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-arm-small"
  token                = var.azp_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.large"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"
  token_name           = "azp_token"

  providers = {
    aws = aws
  }
}

### Github
## arm64

module "gh-arm-build-pool" {
  source = "./cached-build-asg"

  ami_prefix           = "envoy-gh-build-arm64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-gh-arm64-large"
  token                = var.gh_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.8xlarge", "m6g.16xlarge", "m6gd.8xlarge", "m6gd.16xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"
  token_name           = "gh_token"

  providers = {
    aws = aws
  }
}

module "gh-small-arm-build-pool" {
  source = "./small-build-asg"

  ami_prefix           = "envoy-gh-build-arm64"
  aws_account_id       = "457956385456"
  pool_name            = "envoy-gh-arm64-small"
  token                = var.gh_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.large"]
  token_name           = "gh_token"

  providers = {
    aws = aws
  }
}
