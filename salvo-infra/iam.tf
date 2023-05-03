# Permissions for the Cleanup Lambda that deletes unused AMIs and snapshots.
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "salvo_lambda_role" {
  name               = "salvo_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
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

resource "aws_iam_role_policy" "log_perms" {
  name = "azp_dereg_lambda_log_perms"
  role = aws_iam_role.salvo_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_logs.json
}

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

resource "aws_iam_role" "salvo_cleanup_lambda_role" {
  name               = "salvo_cleanup_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_role_policy" "log_perms_cleanup" {
  name = "cleanup_lambda_log_perms"
  role = aws_iam_role.salvo_cleanup_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_logs.json
}

resource "aws_iam_role_policy" "cleanup_ec2_perms" {
  name = "cleanup_lambda_ec2_perms"
  role = aws_iam_role.salvo_cleanup_lambda_role.id

  policy = data.aws_iam_policy_document.lambda_cleanup_ami_permissions.json
}
