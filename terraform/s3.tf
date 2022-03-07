resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket        = "ugt-report-incidents-lambda-fns"
  force_destroy = true
}

# Lambda (NodeJS) to Store Incident
data "archive_file" "lambda_storeIncidentHandler_file" {
  type = "zip"

  source_dir  = "${path.module}/../lambdas/storeIncidentHandler"
  output_path = "${path.module}/storeIncidentHandler.zip"
}

resource "aws_s3_object" "lambda_storeIncidentHandler" {
  bucket = aws_s3_bucket.ugt_lambda_states.id

  key    = "storeIncidentHandler.zip"
  source = data.archive_file.lambda_storeIncidentHandler_file.output_path

  etag = filemd5(data.archive_file.lambda_storeIncidentHandler_file.output_path)
}