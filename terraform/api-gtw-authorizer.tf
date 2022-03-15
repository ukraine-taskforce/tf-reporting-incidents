# Lambda: Authorizer Handler
resource "aws_iam_role" "lambda-authorizer-role" {
  name = "lambda-authorizer"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "cloudwatch_writer_policy-document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_policy" "cloudwatch_writer_policy" {
  name   = "cloudwatch_writer_policy"
  path   = "/c/"
  policy = data.aws_iam_policy_document.cloudwatch_writer_policy-document.json
}

resource "aws_iam_role_policy_attachment" "lambda-authorizer-role_cloudwatch_writer_policy" {
  role       = aws_iam_role.lambda-authorizer-role.name
  policy_arn = aws_iam_policy.cloudwatch_writer_policy.arn
}

# Lambda: Authorizer function
data "archive_file" "authorizerHandler_file" {
  type = "zip"

  source_dir  = "${path.module}/../lambdas/authorizerHandler"
  output_path = "${path.module}/authorizerHandler.zip"
}

resource "aws_lambda_function" "authorizerHandler" {
  function_name = "ApiGatewayAuthorizer"

  filename         = data.archive_file.authorizerHandler_file.output_path
  source_code_hash = data.archive_file.authorizerHandler_file.output_base64sha256

  runtime = "nodejs14.x"
  handler = "index.handler"

  role = aws_iam_role.lambda-authorizer-role.arn
}

resource "aws_cloudwatch_log_group" "authorizerHandler_logGroup" {
  name              = "/aws/lambda/${aws_lambda_function.authorizerHandler.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "authorizerHandler_ApiGtwPermission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizerHandler.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.reporting-incidents.execution_arn}/*/*/*"
}

# API Gateway: User Authorizer
resource "aws_api_gateway_authorizer" "api-gateway-authorizer" {
  name                   = "apiGatewayAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.reporting-incidents.id
  authorizer_uri         = aws_lambda_function.authorizerHandler.invoke_arn
  authorizer_credentials = aws_iam_role.apiSQS.arn
  type                   = "TOKEN"
}