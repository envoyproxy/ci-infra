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
