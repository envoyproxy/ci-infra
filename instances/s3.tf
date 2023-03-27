resource "aws_s3_bucket" "token" {
  bucket = "cncf-envoy-token"
  acl    = "private"

  tags = {
    Environment = "Production"
  }
  provider = aws.us-east-1
}

resource "aws_s3_bucket" "build-cache" {
  bucket = "envoy-ci-build-cache-us-east-2"
  acl    = "private"

  tags = {
    Environment = "Production"
  }
}
