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

variable "db_password" {
  description = "Master password. Pass via TF_VAR_db_password, never commit it."
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Whether to run a standby in a second AZ (production HA)."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
