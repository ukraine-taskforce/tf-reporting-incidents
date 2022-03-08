resource "random_password" "master_password" {
  length  = 16
  special = false
}

resource "aws_rds_cluster" "cluster" {
  engine                  = "aurora-postgresql"
  engine_mode             = "serverless"
  enable_http_endpoint    = "true"
  availability_zones      = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  backup_retention_period = 5
  preferred_backup_window = "04:00-05:00"
  deletion_protection     = true

  cluster_identifier      = "reporting-incidents-serverless"
  database_name           = "postgres"
  master_username         = "root"
  master_password         = random_password.master_password.result

  scaling_configuration {
    max_capacity             = 16
    min_capacity             = 2
  }
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "rds/aurora/${aws_rds_cluster.cluster.cluster_identifier}"
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id     = aws_secretsmanager_secret.rds_credentials.id
  secret_string = <<EOF
{
  "username": "${aws_rds_cluster.cluster.master_username}",
  "password": "${random_password.master_password.result}",
  "engine": "postgres",
  "host": "${aws_rds_cluster.cluster.endpoint}",
  "port": ${aws_rds_cluster.cluster.port},
  "dbClusterIdentifier": "${aws_rds_cluster.cluster.cluster_identifier}"
}
EOF
}