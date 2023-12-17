resource "aws_s3_bucket" "token" {
  bucket = "cncf-envoy-token"
  acl    = "private"

  tags = {
    Environment = "Production"
  }
  provider = aws.us-east-1
}

resource "aws_s3_bucket_public_access_block" "token" {
  bucket = aws_s3_bucket.token.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  provider = aws.us-east-1
}

resource "aws_s3_bucket" "build-cache" {
  bucket = "envoy-ci-build-cache-us-east-2"
  acl    = "private"

  tags = {
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "build-cache" {
  bucket = aws_s3_bucket.build-cache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
