resource "aws_sqs_queue" "reporting-incidents_sqs" {
  name                      = "reporting-incidents-queue"
  delay_seconds             = 0
  receive_wait_time_seconds = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reporting-incidents_sqs-dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "reporting-incidents_sqs-dlq" {
  name                      = "reporting-incidents-dlq"
  delay_seconds             = 0
  receive_wait_time_seconds = 10
}