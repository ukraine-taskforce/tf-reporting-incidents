resource "aws_sqs_queue" "reporting-incidents_sqs" {
  name                      = "reporting-incidents-queue"
  delay_seconds             = 0
  receive_wait_time_seconds = 10
}

#TODO: Create dead letter queue