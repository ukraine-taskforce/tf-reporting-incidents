resource "aws_dynamodb_table" "incident-intermediate-state" {
  name           = "IncidentIntermediateState"
  hash_key       = "UserID"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "UserID"
    type = "N"
  }
}