provider "aws" {
  region  = "us-east-2"
}

provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
}

module "x64-large-build-pool" {
  source = "./azp-build-asg"

  ami_prefix           = "envoy-azp-x64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "x64-large"
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

module "arm-build-pool" {
  source = "./azp-build-asg"

  ami_prefix           = "envoy-azp-arm64"
  aws_account_id       = "457956385456"
  azp_pool_name        = "arm-large"
  azp_token            = var.azp_token
  disk_size_gb         = 1000
  idle_instances_count = 1
  instance_types       = ["r6g.8xlarge"]
  bazel_cache_bucket   = aws_s3_bucket.build-cache.bucket
  cache_prefix         = "public-arm64"

  providers = {
    aws = aws
  }
}
