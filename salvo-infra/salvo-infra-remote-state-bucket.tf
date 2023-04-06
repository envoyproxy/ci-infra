# The S3 bucket where Terraform for the salvo infra stores its state.

resource "aws_s3_bucket" "salvo-infra-remote-state-bucket" {
  bucket = "salvo-infra-tf-remote-state-us-west-1"

  tags = {
    Environment = "Production"
  }
}

resource "aws_s3_bucket_versioning" "salvo-infra-remote-state-bucket-versioning" {
  bucket = aws_s3_bucket.salvo-infra-remote-state-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "salvo-infra-remote-state-bucket-lifecycle" {
  bucket = aws_s3_bucket.salvo-infra-remote-state-bucket.id

  rule {
    id     = "keep-100-noncurrent-versions-for-a-year"
    status = "Enabled"
    noncurrent_version_expiration {
      newer_noncurrent_versions = 100
      noncurrent_days           = 365
    }
  }
}

terraform {
  backend "s3" {
    bucket = "salvo-infra-tf-remote-state-us-west-1"
    key    = "salvo/infra/terraform.tfstate"
    region = "us-west-1"
  }

  required_version = ">= 1.4"
}
