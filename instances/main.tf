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
  source = "./azp-cached-build-asg"

  ami_prefix           = "envoy-azp-build-x64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "envoy-x64-large"
  azp_token            = var.azp_token
  disk_size_gb         = 2000
  idle_instances_count = 1
  instance_types       = ["r5a.8xlarge", "r5.8xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-x64"

  providers = {
    aws = aws
  }
}

module "small-x64-build-pool" {
  source = "./azp-small-build-asg"

  ami_prefix           = "envoy-azp-build-x64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "envoy-x64-small"
  azp_token            = var.azp_token
  idle_instances_count = 2
  instance_types       = ["m6i.xlarge"]

  providers = {
    aws = aws
  }
}

module "nano-x64-minimal-pool" {
  source = "./azp-nano-asg"

  ami_prefix           = "envoy-azp-minimal-x64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "x64-nano"
  azp_token            = var.azp_token
  disk_size_gb         = 10
  idle_instances_count = 1
  instance_types       = ["t3.nano"]

  providers = {
    aws = aws
  }
}

## arm64

module "arm-build-pool" {
  source = "./azp-cached-build-asg"

  ami_prefix           = "envoy-azp-build-arm64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "envoy-arm-large"
  azp_token            = var.azp_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.16xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"

  providers = {
    aws = aws
  }
}

module "small-arm-build-pool" {
  source = "./azp-cached-build-asg"

  ami_prefix           = "envoy-azp-build-arm64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "envoy-arm-small"
  azp_token            = var.azp_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["m6g.large"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"

  providers = {
    aws = aws
  }
}
