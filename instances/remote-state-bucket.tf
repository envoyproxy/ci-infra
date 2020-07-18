resource "aws_s3_bucket" "remote-state-bucket" {
  bucket = "envoy-build-tf-remote-state-us-east-2"
  acl    = "private"

  tags = {
    Environment = "Production"
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
