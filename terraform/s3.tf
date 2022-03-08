resource "aws_s3_bucket" "ugt_lambda_states" {
  bucket        = "ugt-report-incidents-lambda-fns"
  force_destroy = true
}