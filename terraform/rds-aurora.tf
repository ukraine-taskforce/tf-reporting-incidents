resource "aws_rds_cluster" "cluster" {
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  availability_zones      = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  backup_retention_period = 5
  preferred_backup_window = "04:00-05:00"

  cluster_identifier      = "reporting-incidents-aurora-cluster"
  database_name           = "postgres"
  master_username         = "root"
  master_password         = "ZB2ys9D44Nj*54+g"
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  identifier         = "reporting-incidents-aurora-${count.index}"
  count              = 1
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = "db.t3.medium"
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version

  publicly_accessible = true
}