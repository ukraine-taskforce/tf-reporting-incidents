resource "aws_dynamodb_table" "ReportsOnIncidents-table" {
  name           = "ReportsOnIncidents"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}