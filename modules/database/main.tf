# RDS subnet group spanning the private subnets across >=2 AZs.
resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.project_name}-db-subnet-group" })
}

# KMS key for RDS Performance Insights encryption.
resource "aws_kms_key" "db" {
  description             = "KMS key for RDS Performance Insights encryption."
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_key_policy" "db" {
  key_id = aws_kms_key.db.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "db" {
  name          = "alias/${var.project_name}-db-key"
  target_key_id = aws_kms_key.db.key_id
}

data "aws_caller_identity" "current" {}

# Managed database instance. Intentionally stripped of some production guardrails
# (deletion_protection=false, skip_final_snapshot=true) so teardown is easy.
# See README.md "Production hardening" for the full list of tradeoffs.
#trivy:ignore:AWS-0176 -- IAM auth omitted for simpler demo setup.
#trivy:ignore:AWS-0177 -- Deletion protection disabled for easy demo teardown.
resource "aws_db_instance" "this" {
  identifier     = "${var.project_name}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = 7
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade      = true
  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.db.arn

  enabled_cloudwatch_logs_exports = var.engine == "postgres" ? ["postgresql"] : ["error", "general", "slowquery"]

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.tags, { Name = "${var.project_name}-db" })
}
