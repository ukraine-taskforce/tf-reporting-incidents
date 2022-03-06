resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket        = "ugt-report-incidents-lambda-fns"
  force_destroy = true
}

# Write to DynamoDB
data "archive_file" "lambda_putDynamoDBHandler_file" {
  type = "zip"

  source_dir  = "${path.module}/../lambdas/putDynamoDBHandler"
  output_path = "${path.module}/putDynamoDBHandler.zip"
}

resource "aws_s3_object" "lambda_putDynamoDBHandler" {
  bucket = aws_s3_bucket.ugt_lambda_states.id

  key    = "putDynamoDBHandler.zip"
  source = data.archive_file.lambda_putDynamoDBHandler_file.output_path

  etag = filemd5(data.archive_file.lambda_putDynamoDBHandler_file.output_path)
}