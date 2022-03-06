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

resource "aws_iam_role" "reportsOnIncidents-sqs-dynamodb" {
  name = "lambda_sqs_dynamodb"

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

data "template_file" "reportsOnIncidents-sqs-dynamodb-policyDocument" {
  template = file("policies/lambda-permission.json")
  vars = {
    sqs_arn = aws_sqs_queue.reporting-incidents_sqs.arn
    dynamodbTable_arn = aws_dynamodb_table.ReportsOnIncidents-table.arn
  }
}

resource "aws_iam_policy" "reportsOnIncidents-sqs-dynamodb-policy" {
  name   = "lambda_sqs-dynamodb-cloudwatch-policy"
  policy = data.template_file.reportsOnIncidents-sqs-dynamodb-policyDocument.rendered
}

resource "aws_iam_role_policy_attachment" "reportsOnIncidents-sqs-dynamodb" {
  role       = aws_iam_role.reportsOnIncidents-sqs-dynamodb.name
  policy_arn = aws_iam_policy.reportsOnIncidents-sqs-dynamodb-policy.arn
}