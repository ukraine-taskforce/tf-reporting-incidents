# Lambda: Store reported incidents
resource "null_resource" "lambda_storeIncidentHandler_installDependencies" {
  provisioner "local-exec" {
    working_dir = "${path.module}/../lambdas/storeIncidentHandler"
    command = "npm install"
  }

  triggers = {
    rerun_every_time = uuid()
  }
}

data "archive_file" "lambda_storeIncidentHandler_file" {
  type = "zip"

  source_dir  = "${path.module}/../lambdas/storeIncidentHandler"
  output_path = "${path.module}/storeIncidentHandler.zip"

  depends_on = [ null_resource.lambda_storeIncidentHandler_installDependencies ]
}

resource "aws_lambda_function" "reportsOnIncidents_lambdaFn" {
  function_name = "ReportOnIncidents-StoreIncident"

#  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
#  s3_key    = aws_s3_object.lambda_storeIncidentHandler.key
  filename         = data.archive_file.lambda_storeIncidentHandler_file.output_path
  source_code_hash = data.archive_file.lambda_storeIncidentHandler_file.output_base64sha256

  runtime = "nodejs14.x"
  handler = "index.handler"

  role = aws_iam_role.reportsOnIncidents-lambda-role.arn

  environment {
    variables = {
      SECRET_ARN : aws_secretsmanager_secret.rds_credentials.arn,
      RDS_DB_ARN : aws_rds_cluster.cluster.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "reportsOnIncidents_logGroup" {
  name              = "/aws/lambda/${aws_lambda_function.reportsOnIncidents_lambdaFn.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "reportsOnIncidents_allows_sqs_to_trigger_lambda" {
  statement_id  = "AllowExecutionFromSQS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reportsOnIncidents_lambdaFn.function_name
  principal     = "sqs.amazonaws.com"
  source_arn    = aws_sqs_queue.reporting-incidents_sqs.arn
}

# Trigger lambda on message to SQS
resource "aws_lambda_event_source_mapping" "reportsOnIncidents_event_source_mapping" {
  batch_size       = 1
  event_source_arn = aws_sqs_queue.reporting-incidents_sqs.arn
  enabled          = true
  function_name    = aws_lambda_function.reportsOnIncidents_lambdaFn.arn
}

###### Bot client lambda

resource "random_id" "id" {
  byte_length = 8
}

resource "random_id" "random_path" {
  byte_length = 16
}

resource "aws_secretsmanager_secret" "telegram-bot-token" {
  name = "lambda/telegram-bot-client/token"
}

resource "aws_secretsmanager_secret_version" "telegram-bot-token" {
  secret_id = aws_secretsmanager_secret.telegram-bot-token.id
  secret_string = var.telegram_token
}

variable "telegram_token" {
  type      = string
  sensitive = true
}

resource "null_resource" "bot-token-lambda-build" {
  triggers = { dependencies_versions = filemd5("../lambdas/bot-client/requirements.txt") }

  provisioner "local-exec" {
    command = "pip install -r ../lambdas/bot-client/requirements.txt -t ../lambdas/bot-client/ --upgrade"
  }
}

data "archive_file" "bot-token-archive" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/bot-client/"
  output_path = "${path.module}/bot-client.zip"

  depends_on = [null_resource.bot-token-lambda-build]
}

resource "aws_lambda_function" "bot-client-lambda" {
  function_name = "${random_id.id.hex}-telegram-bot"

  filename         = data.archive_file.bot-token-archive.output_path
  source_code_hash = data.archive_file.bot-token-archive.output_base64sha256
  environment {
    variables = {
      domain                    = aws_apigatewayv2_api.bot-client-api.api_endpoint
      path_key                  = random_id.random_path.hex
      token_parameter           = aws_secretsmanager_secret.telegram-bot-token.arn
      incident_state_table_name = aws_dynamodb_table.incident-intermediate-state.name
      sqs_url                   = aws_sqs_queue.reporting-incidents_sqs.url
    }
  }

  timeout = 30
  handler = "main.lambda_handler"
  runtime = "python3.9"
  role    = aws_iam_role.bot-client-lambda-role.arn
}

data "aws_lambda_invocation" "bot-set_webhook" {
  function_name = aws_lambda_function.bot-client-lambda.function_name

  input = <<JSON
{
  "body": {
    "setWebhook": true
  }
}
JSON
}

resource "aws_cloudwatch_log_group" "botClientLogGroup" {
  name              = "/aws/lambda/${aws_lambda_function.bot-client-lambda.function_name}"
  retention_in_days = 14
}
