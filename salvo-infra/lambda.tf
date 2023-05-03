# A function that removes unused AMIs and Snapshots.
#
# To create the lambda-cleanup.zip perform:
#   1) cd ../instances/azp-cleanup-snapshots/
#   2) npm run build
#
# Also see the https://github.com/envoyproxy/ci-infra/blob/main/MAINTENANCE.md.
resource "aws_lambda_function" "cleanup_lambda" {
  filename      = "../instances/lambda-cleanup.zip"
  function_name = "ami_cleanup_lambda"
  role          = aws_iam_role.salvo_cleanup_lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs12.x"

  memory_size = 512
  timeout     = 180

  source_code_hash = filebase64sha256("../instances/lambda-cleanup.zip")
}
