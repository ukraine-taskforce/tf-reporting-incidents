resource "aws_iam_role" "apiSQS" {
  name = "apigateway_sqs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "gateway_policy" {
  template = file("policies/api-gateway-permission.json")
  vars = {
    sqs_arn = aws_sqs_queue.reporting-incidents_sqs.arn
  }
}

resource "aws_iam_policy" "api_policy" {
  name   = "api-sqs-cloudwatch-policy"
  policy = data.template_file.gateway_policy.rendered
}

resource "aws_iam_role_policy_attachment" "api_exec_role" {
  role       = aws_iam_role.apiSQS.name
  policy_arn = aws_iam_policy.api_policy.arn
}

resource "aws_iam_role" "reportsOnIncidents-lambda-role" {
  name = "lambda-role"

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

data "template_file" "reportsOnIncidents-sqs-policyDocument" {
  template = file("policies/lambda-permission.json")
  vars = {
    sqs_arn = aws_sqs_queue.reporting-incidents_sqs.arn
  }
}

resource "aws_iam_policy" "reportsOnIncidents-sqs-policy" {
  name   = "lambda_sqs-cloudwatch-policy"
  policy = data.template_file.reportsOnIncidents-sqs-policyDocument.rendered
}

resource "aws_iam_role_policy_attachment" "reportsOnIncidents-sqs" {
  role       = aws_iam_role.reportsOnIncidents-lambda-role.name
  policy_arn = aws_iam_policy.reportsOnIncidents-sqs-policy.arn
}

data "template_file" "bot-client-policy" {
  template = file("policies/bot-permission.json")
  vars = {
    dynamodb_arn = aws_dynamodb_table.incident-intermediate-state.arn
    ssm_arn = aws_ssm_parameter.telegram-bot-token.arn
    sqs_arn = aws_sqs_queue.reporting-incidents_sqs.arn
  }
}

resource "aws_iam_role_policy" "lambda_exec_role" {
  role   = aws_iam_role.bot-client-lambda-role.id
  policy = data.template_file.bot-client-policy.rendered
}

resource "aws_iam_role" "bot-client-lambda-role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}