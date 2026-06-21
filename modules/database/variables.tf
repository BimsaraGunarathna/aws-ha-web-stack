variable "project_name" {
  description = "Name prefix for the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group (need >= 2 AZs)."
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security group ID for the database."
  type        = string
}

variable "engine" {
  description = "Database engine."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username."
  type        = string
  default     = "appadmin"
}

variable "multi_az" {
  description = "Whether to run a standby in a second AZ (production HA)."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (dev convenience vs safety)."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block accidental deletion of the RDS instance. Set false in dev to allow terraform destroy."
  type        = bool
  default     = true
}

variable "storage_type" {
  description = "RDS storage type (gp3, gp2, io1, ...)."
  type        = string
  default     = "gp3"
}

variable "backup_retention_period" {
  description = "Days to retain automated backups."
  type        = number
  default     = 7
}

variable "performance_insights_enabled" {
  description = "Enable RDS Performance Insights."
  type        = bool
  default     = true
}

variable "kms_deletion_window_days" {
  description = "Waiting period (days) before the DB KMS key is deleted."
  type        = number
  default     = 7
}

variable "secret_recovery_window_days" {
  description = "Recovery window (days) for the Secrets Manager password secret."
  type        = number
  default     = 7
}

variable "password_length" {
  description = "Length of the generated master password."
  type        = number
  default     = 24
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
