# Lambda: Store reported incidents
resource "aws_lambda_function" "reportsOnIncidents_lambdaFn" {
  function_name = "ReportOnIncidents-StoreIncident"

  s3_bucket = aws_s3_bucket.ugt_lambda_states.id
  s3_key    = aws_s3_object.lambda_storeIncidentHandler.key

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_storeIncidentHandler_file.output_base64sha256

  role = aws_iam_role.reportsOnIncidents-lambda-role.arn

  environment {
    variables = {
      SECRET_ARN: aws_secretsmanager_secret.rds_credentials.arn,
      RDS_DB_ARN: aws_rds_cluster.cluster.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "reportsOnIncidents_logGroup" {
  name = "/aws/lambda/${aws_lambda_function.reportsOnIncidents_lambdaFn.function_name}"
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
  event_source_arn =  aws_sqs_queue.reporting-incidents_sqs.arn
  enabled          = true
  function_name    =  aws_lambda_function.reportsOnIncidents_lambdaFn.arn
}

