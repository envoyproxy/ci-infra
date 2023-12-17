#########################################################################################
# Permissions for the Lambda to Deregister Instances.                                   #
#########################################################################################

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "lambda_ec2_permissions" {
  statement {
    actions = [
      # Get the Tags to identify the Pool Name.
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "azp_dereg_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "log_perms" {
  name = "azp_dereg_lambda_log_perms"
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_iam_role_policy" "ec2_perms" {
  name = "azp_dereg_lambda_ec2_perms"
  role = aws_iam_role.lambda_role.id

  policy = data.aws_iam_policy_document.lambda_ec2_permissions.json
}

#########################################################################################
# Permissions for the Cleanup Lambda.                                                   #
#########################################################################################

data "aws_iam_policy_document" "lambda_cleanup_ami_permissions" {
  statement {
    actions = [
      # Allow it to describe things in EC2 to not only describe the AMIs
      # but also find all places they're being used.
      "ec2:Describe*",
      # Allow it to deregister an AMI so it can't be used anymore.
      "ec2:DeregisterImage",
      # Allow it to delete the snapshot of the AMI.
      "ec2:DeleteSnapshot",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "cleanup_lambda_role" {
  name               = "cleanup_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "log_perms_cleanup" {
  name = "cleanup_lambda_log_perms"
  role = aws_iam_role.cleanup_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_iam_role_policy" "cleanup_ec2_perms" {
  name = "cleanup_lambda_ec2_perms"
  role = aws_iam_role.cleanup_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_cleanup_ami_permissions.json
}

### Github OIDC

module "iam_github_oidc_provider" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  tags = {
    Environment = "Production"
  }
}

locals {
  s3_untrusted_policy = {
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ],
        Resource = [
          "arn:aws:s3:::envoy-ci-cache-us-east-2/*",
          "arn:aws:s3:::envoy-ci-cache-us-east-2",
        ],
      },
    ],
  }
  s3_untrusted_policy_json = jsonencode(local.s3_untrusted_policy)
  s3_trusted_policy = {
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ],
        Resource = [
          "arn:aws:s3:::envoy-ci-cache-trusted-us-east-2/*",
          "arn:aws:s3:::envoy-ci-cache-trusted-us-east-2",
        ],
      },
    ],
  }
  s3_trusted_policy_json = jsonencode(local.s3_trusted_policy)
}

module "iam_github_oidc_untrusted_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  name = "GithubOIDCRoleS3CacheUntrusted"
  subjects = [
    "envoyproxy/envoy:*",
    "envoyproxy/envoy-ci-staging:*",
    "envoyproxy/envoy-setec:*",
  ]

  policies = {
     S3BucketAccess = aws_iam_policy.s3_untrusted_policy.arn
  }

  tags = {
    Environment = "Production"
  }
}

resource "aws_iam_policy" "s3_untrusted_policy" {
  name        = "S3UntrustedCacheBucketAccessPolicy"
  description = "Policy for untrusted s3 cache bucket access"
  policy      = local.s3_untrusted_policy_json
}

resource "aws_iam_role_policy_attachment" "s3_untrusted_attachment" {
  role       = module.iam_github_oidc_untrusted_role.name
  policy_arn = aws_iam_policy.s3_untrusted_policy.arn
}

## Trusted cache

module "iam_github_oidc_trusted_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  name = "GithubOIDCRoleS3CacheTrusted"
  subjects = [
    "envoyproxy/envoy:*",
    "envoyproxy/envoy-ci-staging:*",
    "envoyproxy/envoy-setec:*",
  ]

  policies = {
     S3BucketAccess = aws_iam_policy.s3_trusted_policy.arn
  }

  tags = {
    Environment = "Production"
  }
}

resource "aws_iam_policy" "s3_trusted_policy" {
  name        = "S3TrustedCacheBucketAccessPolicy"
  description = "Policy for trusted s3 cache bucket access"
  policy      = local.s3_trusted_policy_json
}

resource "aws_iam_role_policy_attachment" "s3_trusted_attachment" {
  role       = module.iam_github_oidc_trusted_role.name
  policy_arn = aws_iam_policy.s3_trusted_policy.arn
}
