resource "aws_s3_bucket" "remote-state-bucket" {
  bucket = "envoy-build-tf-remote-state-us-east-2"
  acl    = "private"

  tags = {
    Environment = "Production"
  }
}

resource "aws_s3_bucket_versioning" "remote-state-bucket-versioning" {
  bucket = aws_s3_bucket.remote-state-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "remote-state-bucket-lifecycle" {
  bucket = aws_s3_bucket.remote-state-bucket.id

  rule {
    id = "keep-100-noncurrent-versions-for-a-year"
    status = "Enabled"
    noncurrent_version_expiration {
      newer_noncurrent_versions = 100
      noncurrent_days = 365
    }
  }
}

terraform {
  backend "s3" {
    bucket = "envoy-build-tf-remote-state-us-east-2"
    key    = "github/envoyproxy/envoy-build-tools/terraform.tfstate"
    region = "us-east-2"
  }

  required_version = ">= 0.12"
}
